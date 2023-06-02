// Copyright 2023 The MediaPipe Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

#include "mediapipe/framework/formats/classification.pb.h"
#include "mediapipe/framework/formats/landmark.pb.h"
#include "mediapipe/framework/formats/matrix_data.pb.h"
#include "mediapipe/tasks/cc/vision/face_geometry/proto/face_geometry.pb.h"
#import "mediapipe/tasks/ios/common/sources/MPPCommon.h"
#import "mediapipe/tasks/ios/components/containers/utils/sources/MPPClassificationResult+Helpers.h"
#import "mediapipe/tasks/ios/components/containers/utils/sources/MPPDetection+Helpers.h"
#import "mediapipe/tasks/ios/components/containers/utils/sources/MPPLandmark+Helpers.h"
#import "mediapipe/tasks/ios/test/vision/utils/sources/MPPImage+TestUtils.h"
#include "mediapipe/tasks/ios/test/vision/utils/sources/parse_proto_utils.h"
#import "mediapipe/tasks/ios/vision/face_landmarker/sources/MPPFaceLandmarker.h"
#import "mediapipe/tasks/ios/vision/face_landmarker/sources/MPPFaceLandmarkerResult.h"

using NormalizedLandmarkListProto = ::mediapipe::NormalizedLandmarkList;
using ClassificationListProto = ::mediapipe::ClassificationList;
using FaceGeometryProto = ::mediapipe::tasks::vision::face_geometry::proto::FaceGeometry;
using ::mediapipe::tasks::ios::test::vision::utils::get_proto_from_pbtxt;

static NSString *const kPbFileExtension = @"pbtxt";

typedef NSDictionary<NSString *, NSString *> ResourceFileInfo;

static ResourceFileInfo *const kPortraitImage =
    @{@"name" : @"portrait", @"type" : @"jpg", @"orientation" : @(UIImageOrientationUp)};
static ResourceFileInfo *const kPortraitRotatedImage =
    @{@"name" : @"portrait_rotated", @"type" : @"jpg", @"orientation" : @(UIImageOrientationRight)};
static ResourceFileInfo *const kCatImage = @{@"name" : @"cat", @"type" : @"jpg"};
static ResourceFileInfo *const kPortraitExpectedLandmarksName =
    @{@"name" : @"portrait_expected_face_landmarks", @"type" : kPbFileExtension};
static ResourceFileInfo *const kPortraitExpectedBlendshapesName =
    @{@"name" : @"portrait_expected_blendshapes", @"type" : kPbFileExtension};
static ResourceFileInfo *const kPortraitExpectedGeometryName =
    @{@"name" : @"portrait_expected_face_geometry", @"type" : kPbFileExtension};
static NSString *const kFaceLandmarkerModelName = @"face_landmarker_v2";
static NSString *const kFaceLandmarkerWithBlendshapesModelName =
    @"face_landmarker_v2_with_blendshapes";
static NSString *const kExpectedErrorDomain = @"com.google.mediapipe.tasks";

constexpr float kLandmarkErrorThreshold = 0.03f;
constexpr float kBlendshapesErrorThreshold = 0.1f;
constexpr float kFacialTransformationMatrixErrorThreshold = 0.2f;

#define AssertEqualErrors(error, expectedError)              \
  XCTAssertNotNil(error);                                    \
  XCTAssertEqualObjects(error.domain, expectedError.domain); \
  XCTAssertEqual(error.code, expectedError.code);            \
  XCTAssertEqualObjects(error.localizedDescription, expectedError.localizedDescription)

@interface MPPFaceLandmarkerTests : XCTestCase {
}
@end

@implementation MPPFaceLandmarkerTests

#pragma mark General Tests

- (void)testCreateFaceLandmarkerWithMissingModelPathFails {
  NSString *modelPath = [MPPFaceLandmarkerTests filePathWithName:@"" extension:@""];

  NSError *error = nil;
  MPPFaceLandmarker *faceLandmarker = [[MPPFaceLandmarker alloc] initWithModelPath:modelPath
                                                                             error:&error];
  XCTAssertNil(faceLandmarker);

  NSError *expectedError = [NSError
      errorWithDomain:kExpectedErrorDomain
                 code:MPPTasksErrorCodeInvalidArgumentError
             userInfo:@{
               NSLocalizedDescriptionKey :
                   @"INVALID_ARGUMENT: ExternalFile must specify at least one of 'file_content', "
                   @"'file_name', 'file_pointer_meta' or 'file_descriptor_meta'."
             }];
  AssertEqualErrors(error, expectedError);
}

#pragma mark Image Mode Tests

- (void)testDetectWithImageModeAndPotraitSucceeds {
  NSString *modelPath = [MPPFaceLandmarkerTests filePathWithName:kFaceLandmarkerModelName
                                                       extension:@"task"];
  MPPFaceLandmarker *faceLandmarker = [[MPPFaceLandmarker alloc] initWithModelPath:modelPath
                                                                             error:nil];
  NSArray<MPPNormalizedLandmark *> *expectedLandmarks =
      [MPPFaceLandmarkerTests expectedLandmarksFromFileInfo:kPortraitExpectedLandmarksName];
  [self assertResultsOfDetectInImageWithFileInfo:kPortraitImage
                             usingFaceLandmarker:faceLandmarker
                       containsExpectedLandmarks:expectedLandmarks
                             expectedBlendshapes:NULL
                    expectedTransformationMatrix:NULL];
}

- (void)testDetectWithImageModeAndPotraitAndFacialTransformationMatrixesSucceeds {
  MPPFaceLandmarkerOptions *options =
      [self faceLandmarkerOptionsWithModelName:kFaceLandmarkerModelName];
  options.outputFacialTransformationMatrixes = YES;
  MPPFaceLandmarker *faceLandmarker = [[MPPFaceLandmarker alloc] initWithOptions:options error:nil];

  NSArray<MPPNormalizedLandmark *> *expectedLandmarks =
      [MPPFaceLandmarkerTests expectedLandmarksFromFileInfo:kPortraitExpectedLandmarksName];
  MPPTransformMatrix *expectedTransformationMatrix = [MPPFaceLandmarkerTests
      expectedTransformationMatrixFromFileInfo:kPortraitExpectedGeometryName];
  [self assertResultsOfDetectInImageWithFileInfo:kPortraitImage
                             usingFaceLandmarker:faceLandmarker
                       containsExpectedLandmarks:expectedLandmarks
                             expectedBlendshapes:NULL
                    expectedTransformationMatrix:expectedTransformationMatrix];
}

- (void)testDetectWithImageModeAndNoFaceSucceeds {
  NSString *modelPath = [MPPFaceLandmarkerTests filePathWithName:kFaceLandmarkerModelName
                                                       extension:@"task"];
  MPPFaceLandmarker *faceLandmarker = [[MPPFaceLandmarker alloc] initWithModelPath:modelPath
                                                                             error:nil];
  XCTAssertNotNil(faceLandmarker);

  NSError *error;
  MPPImage *mppImage = [self imageWithFileInfo:kCatImage];
  MPPFaceLandmarkerResult *faceLandmarkerResult = [faceLandmarker detectInImage:mppImage
                                                                          error:&error];
  XCTAssertNil(error);
  XCTAssertNotNil(faceLandmarkerResult);
  XCTAssertEqualObjects(faceLandmarkerResult.faceLandmarks, [NSArray array]);
  XCTAssertEqualObjects(faceLandmarkerResult.faceBlendshapes, [NSArray array]);
  XCTAssertEqualObjects(faceLandmarkerResult.facialTransformationMatrixes, [NSArray array]);
}

#pragma mark Video Mode Tests

- (void)testDetectWithVideoModeAndPotraitSucceeds {
  MPPFaceLandmarkerOptions *options =
      [self faceLandmarkerOptionsWithModelName:kFaceLandmarkerModelName];
  options.runningMode = MPPRunningModeVideo;
  MPPFaceLandmarker *faceLandmarker = [[MPPFaceLandmarker alloc] initWithOptions:options error:nil];

  MPPImage *image = [self imageWithFileInfo:kPortraitImage];
  NSArray<MPPNormalizedLandmark *> *expectedLandmarks =
      [MPPFaceLandmarkerTests expectedLandmarksFromFileInfo:kPortraitExpectedLandmarksName];
  for (int i = 0; i < 3; i++) {
    MPPFaceLandmarkerResult *faceLandmarkerResult = [faceLandmarker detectInVideoFrame:image
                                                               timestampInMilliseconds:i
                                                                                 error:nil];
    [self assertFaceLandmarkerResult:faceLandmarkerResult
           containsExpectedLandmarks:expectedLandmarks
                 expectedBlendshapes:NULL
        expectedTransformationMatrix:NULL];
  }
}

#pragma mark Running Mode Tests

- (void)testDetectFailsWithCallingWrongAPIInImageMode {
  MPPFaceLandmarkerOptions *options =
      [self faceLandmarkerOptionsWithModelName:kFaceLandmarkerModelName];
  MPPFaceLandmarker *faceLandmarker = [[MPPFaceLandmarker alloc] initWithOptions:options error:nil];

  MPPImage *image = [self imageWithFileInfo:kPortraitImage];
  NSError *videoAPICallError;
  XCTAssertFalse([faceLandmarker detectInVideoFrame:image
                            timestampInMilliseconds:0
                                              error:&videoAPICallError]);

  NSError *expectedVideoAPICallError =
      [NSError errorWithDomain:kExpectedErrorDomain
                          code:MPPTasksErrorCodeInvalidArgumentError
                      userInfo:@{
                        NSLocalizedDescriptionKey : @"The vision task is not initialized with "
                                                    @"video mode. Current Running Mode: Image"
                      }];
  AssertEqualErrors(videoAPICallError, expectedVideoAPICallError);
}

- (void)testDetectFailsWithCallingWrongAPIInVideoMode {
  MPPFaceLandmarkerOptions *options =
      [self faceLandmarkerOptionsWithModelName:kFaceLandmarkerModelName];
  options.runningMode = MPPRunningModeVideo;

  MPPFaceLandmarker *faceLandmarker = [[MPPFaceLandmarker alloc] initWithOptions:options error:nil];

  MPPImage *image = [self imageWithFileInfo:kPortraitImage];
  NSError *imageAPICallError;
  XCTAssertFalse([faceLandmarker detectInImage:image error:&imageAPICallError]);

  NSError *expectedImageAPICallError =
      [NSError errorWithDomain:kExpectedErrorDomain
                          code:MPPTasksErrorCodeInvalidArgumentError
                      userInfo:@{
                        NSLocalizedDescriptionKey : @"The vision task is not initialized with "
                                                    @"image mode. Current Running Mode: Video"
                      }];
  AssertEqualErrors(imageAPICallError, expectedImageAPICallError);
}

+ (NSString *)filePathWithName:(NSString *)fileName extension:(NSString *)extension {
  NSString *filePath =
      [[NSBundle bundleForClass:[MPPFaceLandmarkerTests class]] pathForResource:fileName
                                                                         ofType:extension];
  return filePath;
}

+ (NSArray<MPPNormalizedLandmark *> *)expectedLandmarksFromFileInfo:(NSDictionary *)fileInfo {
  NSString *filePath = [self filePathWithName:fileInfo[@"name"] extension:fileInfo[@"type"]];
  NormalizedLandmarkListProto proto;
  if (!get_proto_from_pbtxt([filePath UTF8String], proto).ok()) {
    return nil;
  }
  NSMutableArray<MPPNormalizedLandmark *> *landmarks =
      [NSMutableArray arrayWithCapacity:(NSUInteger)proto.landmark_size()];
  for (const auto &landmarkProto : proto.landmark()) {
    [landmarks addObject:[MPPNormalizedLandmark normalizedLandmarkWithProto:landmarkProto]];
  }
  return landmarks;
}

+ (MPPClassifications *)expectedBlendshapesFromFileInfo:(NSDictionary *)fileInfo {
  NSString *filePath = [self filePathWithName:fileInfo[@"name"] extension:fileInfo[@"type"]];
  ClassificationListProto proto;
  if (!get_proto_from_pbtxt([filePath UTF8String], proto).ok()) {
    return nil;
  }
  return [MPPClassifications classificationsWithClassificationListProto:proto
                                                              headIndex:0
                                                               headName:[NSString string]];
}

+ (MPPTransformMatrix *)expectedTransformationMatrixFromFileInfo:(NSDictionary *)fileInfo {
  NSString *filePath = [self filePathWithName:fileInfo[@"name"] extension:fileInfo[@"type"]];
  FaceGeometryProto proto;
  if (!get_proto_from_pbtxt([filePath UTF8String], proto).ok()) {
    return nil;
  }
  return [[MPPTransformMatrix alloc] initWithData:proto.pose_transform_matrix().packed_data().data()
                                             rows:proto.pose_transform_matrix().rows()
                                          columns:proto.pose_transform_matrix().cols()];
}

- (void)assertFaceLandmarkerResult:(MPPFaceLandmarkerResult *)faceLandmarkerResult
         containsExpectedLandmarks:(NSArray<MPPNormalizedLandmark *> *)expectedLandmarks
               expectedBlendshapes:(nullable MPPClassifications *)expectedBlendshapes
      expectedTransformationMatrix:(nullable MPPTransformMatrix *)expectedTransformationMatrix {
  NSArray<MPPNormalizedLandmark *> *landmarks = faceLandmarkerResult.faceLandmarks[0];
  XCTAssertEqual(landmarks.count, expectedLandmarks.count);
  for (int i = 0; i < landmarks.count; ++i) {
    XCTAssertEqualWithAccuracy(landmarks[i].x, expectedLandmarks[i].x, kLandmarkErrorThreshold,
                               @"index i = %d", i);
    XCTAssertEqualWithAccuracy(landmarks[i].y, expectedLandmarks[i].y, kLandmarkErrorThreshold,
                               @"index i = %d", i);
  }

  if (expectedBlendshapes == NULL) {
    XCTAssertEqualObjects(faceLandmarkerResult.faceBlendshapes, [NSArray array]);
  } else {
    MPPClassifications *blendshapes = faceLandmarkerResult.faceBlendshapes[0];
    NSArray<MPPCategory *> *actualCategories = blendshapes.categories;
    NSArray<MPPCategory *> *expectedCategories = expectedBlendshapes.categories;
    XCTAssertEqual(actualCategories.count, expectedCategories.count);
    for (int i = 0; i < actualCategories.count; ++i) {
      XCTAssertEqual(actualCategories[i].index, expectedCategories[i].index, @"index i = %d", i);
      XCTAssertEqualWithAccuracy(actualCategories[i].score, expectedCategories[i].score,
                                 kBlendshapesErrorThreshold, @"index i = %d", i);
      XCTAssertEqualObjects(actualCategories[i].categoryName, expectedCategories[i].categoryName,
                            @"index i = %d", i);
      XCTAssertEqualObjects(actualCategories[i].displayName, expectedCategories[i].displayName,
                            @"index i = %d", i);
    }
  }

  if (expectedTransformationMatrix == NULL) {
    XCTAssertEqualObjects(faceLandmarkerResult.facialTransformationMatrixes, [NSArray array]);
  } else {
    MPPTransformMatrix *actualTransformationMatrix =
        faceLandmarkerResult.facialTransformationMatrixes[0];
    XCTAssertEqual(actualTransformationMatrix.rows, expectedTransformationMatrix.rows);
    XCTAssertEqual(actualTransformationMatrix.columns, expectedTransformationMatrix.columns);
    for (int i = 0; i < actualTransformationMatrix.rows * actualTransformationMatrix.columns; ++i) {
      XCTAssertEqualWithAccuracy(actualTransformationMatrix.data[i],
                                 expectedTransformationMatrix.data[i],
                                 kFacialTransformationMatrixErrorThreshold, @"index i = %d", i);
    }
  }
}

#pragma mark Face Landmarker Initializers

- (MPPFaceLandmarkerOptions *)faceLandmarkerOptionsWithModelName:(NSString *)modelName {
  NSString *modelPath = [MPPFaceLandmarkerTests filePathWithName:modelName extension:@"task"];
  MPPFaceLandmarkerOptions *faceLandmarkerOptions = [[MPPFaceLandmarkerOptions alloc] init];
  faceLandmarkerOptions.baseOptions.modelAssetPath = modelPath;
  return faceLandmarkerOptions;
}

- (void)assertCreateFaceLandmarkerWithOptions:(MPPFaceLandmarkerOptions *)faceLandmarkerOptions
                       failsWithExpectedError:(NSError *)expectedError {
  NSError *error = nil;
  MPPFaceLandmarker *faceLandmarker =
      [[MPPFaceLandmarker alloc] initWithOptions:faceLandmarkerOptions error:&error];
  XCTAssertNil(faceLandmarker);
  AssertEqualErrors(error, expectedError);
}

#pragma mark Assert Detection Results

- (MPPImage *)imageWithFileInfo:(ResourceFileInfo *)fileInfo {
  UIImageOrientation orientation = (UIImageOrientation)[fileInfo[@"orientation"] intValue];
  MPPImage *image = [MPPImage imageFromBundleWithClass:[MPPFaceLandmarkerTests class]
                                              fileName:fileInfo[@"name"]
                                                ofType:fileInfo[@"type"]
                                           orientation:orientation];
  XCTAssertNotNil(image);
  return image;
}

- (void)assertResultsOfDetectInImageWithFileInfo:(ResourceFileInfo *)fileInfo
                             usingFaceLandmarker:(MPPFaceLandmarker *)faceLandmarker
                       containsExpectedLandmarks:
                           (NSArray<MPPNormalizedLandmark *> *)expectedLandmarks
                             expectedBlendshapes:(nullable MPPClassifications *)expectedBlendshapes
                    expectedTransformationMatrix:
                        (nullable MPPTransformMatrix *)expectedTransformationMatrix {
  MPPImage *mppImage = [self imageWithFileInfo:fileInfo];

  NSError *error;
  MPPFaceLandmarkerResult *faceLandmarkerResult = [faceLandmarker detectInImage:mppImage
                                                                          error:&error];
  XCTAssertNil(error);
  XCTAssertNotNil(faceLandmarkerResult);

  [self assertFaceLandmarkerResult:faceLandmarkerResult
         containsExpectedLandmarks:expectedLandmarks
               expectedBlendshapes:expectedBlendshapes
      expectedTransformationMatrix:expectedTransformationMatrix];
}

@end
