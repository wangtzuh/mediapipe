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

#import "mediapipe/tasks/ios/vision/core/sources/MPPImage.h"
#import "mediapipe/tasks/ios/vision/face_landmarker/sources/MPPFaceLandmarkerOptions.h"
#import "mediapipe/tasks/ios/vision/face_landmarker/sources/MPPFaceLandmarkerResult.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Class that performs face landmark detection on images.
 *
 * The API expects a TFLite model with mandatory TFLite Model Metadata.
 */
NS_SWIFT_NAME(FaceLandmarker)
@interface MPPFaceLandmarker : NSObject

/**
 * Creates a new instance of `MPPFaceLandmarker` from an absolute path to a TensorFlow Lite model
 * file stored locally on the device and the default `MPPFaceLandmarker`.
 *
 * @param modelPath An absolute path to a TensorFlow Lite model file stored locally on the device.
 * @param error An optional error parameter populated when there is an error in initializing the
 * face landmaker.
 *
 * @return A new instance of `MPPFaceLandmarker` with the given model path. `nil` if there is an
 * error in initializing the face landmaker.
 */
- (nullable instancetype)initWithModelPath:(NSString *)modelPath error:(NSError **)error;

/**
 * Creates a new instance of `MPPFaceLandmarker` from the given `MPPFaceLandmarkerOptions`.
 *
 * @param options The options of type `MPPFaceLandmarkerOptions` to use for configuring the
 * `MPPFaceLandmarker`.
 * @param error An optional error parameter populated when there is an error in initializing the
 * face landmaker.
 *
 * @return A new instance of `MPPFaceLandmarker` with the given options. `nil` if there is an error
 * in initializing the face landmaker.
 */
- (nullable instancetype)initWithOptions:(MPPFaceLandmarkerOptions *)options
                                   error:(NSError **)error NS_DESIGNATED_INITIALIZER;

/**
 * Performs face landmark detection on the provided MPPImage using the whole image as region of
 * interest. Rotation will be applied according to the `orientation` property of the provided
 * `MPPImage`. Only use this method when the `MPPFaceLandmarker` is created with
 * `MPPRunningModeImage`.
 *
 * This method supports RGBA images. If your `MPPImage` has a source type of
 * `MPPImageSourceTypePixelBuffer` or `MPPImageSourceTypeSampleBuffer`, the underlying pixel buffer
 * must have one of the following pixel format types:
 * 1. kCVPixelFormatType_32BGRA
 * 2. kCVPixelFormatType_32RGBA
 *
 * If your `MPPImage` has a source type of `MPPImageSourceTypeImage` ensure that the color space is
 * RGB with an Alpha channel.
 *
 * @param image The `MPPImage` on which face landmark detection is to be performed.
 * @param error An optional error parameter populated when there is an error in performing face
 * landmark detection on the input image.
 *
 * @return An `MPPFaceLandmarkerResult` that contains a list of landmarks.
 */
- (nullable MPPFaceLandmarkerResult *)detectInImage:(MPPImage *)image
                                              error:(NSError **)error NS_SWIFT_NAME(detect(image:));

/**
 * Performs face landmark detection on the provided video frame of type `MPPImage` using the whole
 * image as region of interest. Rotation will be applied according to the `orientation` property of
 * the provided `MPPImage`. Only use this method when the `MPPFaceLandmarker` is created with
 * `MPPRunningModeVideo`.
 *
 * This method supports RGBA images. If your `MPPImage` has a source type of
 * `MPPImageSourceTypePixelBuffer` or `MPPImageSourceTypeSampleBuffer`, the underlying pixel buffer
 * must have one of the following pixel format types:
 * 1. kCVPixelFormatType_32BGRA
 * 2. kCVPixelFormatType_32RGBA
 *
 * If your `MPPImage` has a source type of `MPPImageSourceTypeImage` ensure that the color space is
 * RGB with an Alpha channel.
 *
 * @param image The `MPPImage` on which face landmark detection is to be performed.
 * @param timestampInMilliseconds The video frame's timestamp (in milliseconds). The input
 * timestamps must be monotonically increasing.
 * @param error An optional error parameter populated when there is an error in performing face
 * landmark detection on the input image.
 *
 * @return An `MPPFaceLandmarkerResult` that contains a list of landmarks.
 */
- (nullable MPPFaceLandmarkerResult *)detectInVideoFrame:(MPPImage *)image
                                 timestampInMilliseconds:(NSInteger)timestampInMilliseconds
                                                   error:(NSError **)error
    NS_SWIFT_NAME(detect(videoFrame:timestampInMilliseconds:));

- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
