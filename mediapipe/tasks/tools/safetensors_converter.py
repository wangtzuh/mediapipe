"""CkptLoader implementation for loading the Safetensors."""

import array
import enum
import json
import os
from typing import List, Optional

import numpy as np
import torch

from mediapipe.tasks.tools import converter_base


class LayerType(enum.Enum):
  """Enum for layer type."""

  NONE = 0
  ATTENTION = 1  # Layer is part of the attention module.
  FEEDFORWARD = 2  # Layer is part of the feedforward module in the Transformer.
  EMBEDDING = 3  # Layer is the embedding lookup or final projection layer.
  LAYER_NORM = (
      4  # Layer is layer normalization before and after attention layer.
  )

  @classmethod
  def get_layer_type(cls, layer_name: str):
    """Gets the layer type of the given layer name."""
    ffn_layers = [
        "mlp",
    ]
    attn_layers = [
        "self_attn",
    ]
    emb_layers = [
        "embed_tokens",
        "lm_head",
    ]
    layer_norms = [
        "input_layernorm",
        "post_attention_layernorm",
        "final_layernorm",
    ]
    if any(sub_name in layer_name for sub_name in attn_layers):
      return LayerType.ATTENTION
    if any(sub_name in layer_name for sub_name in ffn_layers):
      return LayerType.FEEDFORWARD
    if any(sub_name in layer_name for sub_name in emb_layers):
      return LayerType.EMBEDDING
    if any(sub_name in layer_name for sub_name in layer_norms):
      return LayerType.LAYER_NORM
    else:
      return LayerType.NONE


class StablelmMapper(converter_base.LayerActionMapperBase):
  """LayerActionMapper for handling the StableLM model."""

  # we don't quantize layer norm for stablelm model.
  NON_QUANTIZED_LAYERS = [
      "model.norm.weight",
      "input_layernorm",
      "post_attention_layernorm",
  ]

  def map_to_actions(
      self, layer_name: str
  ) -> Optional[converter_base.QuantizationAction]:
    """Map the given layer name to actions."""
    quantize_axis = None
    quantize_bits = None
    layer_type = LayerType.get_layer_type(layer_name)

    if layer_type != LayerType.LAYER_NORM and layer_name.endswith(".weight"):
      quantize_axis = [0]
      if layer_type == LayerType.FEEDFORWARD:
        quantize_bits = self._feedforward_quant_bits
      elif layer_type == LayerType.ATTENTION:
        quantize_bits = self._attention_quant_bits
      elif layer_type == LayerType.EMBEDDING:
        quantize_bits = self._embedding_quant_bits
    target_name = self.update_target_name(layer_name)

    return converter_base.QuantizationAction(
        tensor_name=layer_name,
        target_name=target_name,
        quantize_axis=quantize_axis,
        quantize_bits=quantize_bits,
        pack_dim=0,
    )

  def update_target_name(self, target_name: str) -> str:
    """Updates the target name to match the tensor name convention."""
    target_name = target_name.replace(
        "model.layers.", "params.lm.transformer.x_layers_"
    )
    target_name = target_name.replace("mlp.up_proj", "ff_layer.ffn_layer1")
    target_name = target_name.replace("mlp.down_proj", "ff_layer.ffn_layer2")
    target_name = target_name.replace(
        "mlp.gate_proj", "ff_layer.ffn_layer1_gate"
    )
    target_name = target_name.replace("input_layernorm", "pre_layer_norm")
    target_name = target_name.replace(
        "pre_layer_norm.weight", "pre_layer_norm.scale"
    )
    target_name = target_name.replace(
        "post_attention_layernorm", "post_layer_norm"
    )
    target_name = target_name.replace(
        "post_layer_norm.weight", "post_layer_norm.scale"
    )
    target_name = target_name.replace("self_attn.q_proj", "self_attention.q")
    target_name = target_name.replace("self_attn.k_proj", "self_attention.k")
    target_name = target_name.replace("self_attn.v_proj", "self_attention.v")
    target_name = target_name.replace("self_attn.o_proj", "self_attention.post")
    target_name = target_name.replace(
        "model.embed_tokens", "params.lm.token_embedding"
    )
    target_name = target_name.replace("model.norm", "params.lm.final_ln")
    target_name = target_name.replace("final_ln.weight", "final_ln.scale")
    target_name = target_name.replace("lm_head", "params.lm.softmax.logits_ffn")
    target_name = target_name.replace(".weight", ".w")

    return target_name


class PhiMapper(converter_base.LayerActionMapperBase):
  """LayerActionMapper for handling the Phi model."""

  def map_to_actions(
      self, layer_name: str
  ) -> Optional[converter_base.QuantizationAction]:
    """Map the given layer name to actions."""
    quantize_axis = None
    quantize_bits = None
    layer_type = LayerType.get_layer_type(layer_name)

    if layer_type != LayerType.LAYER_NORM and layer_name.endswith(".weight"):
      quantize_axis = [0]
      if layer_type == LayerType.FEEDFORWARD:
        quantize_bits = self._feedforward_quant_bits
      elif layer_type == LayerType.ATTENTION:
        quantize_bits = self._attention_quant_bits
      elif layer_type == LayerType.EMBEDDING:
        quantize_bits = self._embedding_quant_bits
    target_name = self.update_target_name(layer_name)

    return converter_base.QuantizationAction(
        tensor_name=layer_name,
        target_name=target_name,
        quantize_axis=quantize_axis,
        quantize_bits=quantize_bits,
        pack_dim=0,
    )

  def update_target_name(self, target_name: str) -> str:
    """Updates the target name to match the tensor name convention."""
    target_name = target_name.replace(
        "model.layers.", "params.lm.transformer.x_layers_"
    )

    layer_type = LayerType.get_layer_type(target_name)
    if layer_type == LayerType.FEEDFORWARD:
      target_name = target_name.replace(".weight", ".linear.w")
      target_name = target_name.replace(".bias", ".bias.b")
      target_name = target_name.replace("mlp.fc1", "ff_layer.ffn_layer1")
      target_name = target_name.replace("mlp.fc2", "ff_layer.ffn_layer2")

    elif layer_type == LayerType.ATTENTION:
      target_name = target_name.replace(".weight", ".linear.w")
      target_name = target_name.replace(".bias", ".bias.b")
      target_name = target_name.replace("self_attn.q_proj", "self_attention.q")
      target_name = target_name.replace("self_attn.k_proj", "self_attention.k")
      target_name = target_name.replace("self_attn.v_proj", "self_attention.v")
      target_name = target_name.replace(
          "self_attn.dense", "self_attention.post"
      )
    elif layer_type == LayerType.EMBEDDING:
      target_name = target_name.replace(
          "model.embed_tokens", "params.lm.token_embedding"
      )
      target_name = target_name.replace(
          "lm_head", "params.lm.softmax.logits_ffn"
      )
      target_name = target_name.replace(
          "logits_ffn.weight", "logits_ffn.linear.w"
      )
      target_name = target_name.replace("logits_ffn.bias", "logits_ffn.bias.b")
    elif layer_type == LayerType.LAYER_NORM:
      target_name = target_name.replace("input_layernorm", "pre_layer_norm")
      target_name = target_name.replace(
          "pre_layer_norm.weight", "pre_layer_norm.scale"
      )
      target_name = target_name.replace(
          "model.final_layernorm", "params.lm.final_ln"
      )
      target_name = target_name.replace("final_ln.weight", "final_ln.scale")
    target_name = target_name.replace(".weight", ".w")
    return target_name


DTYPE_MAP = {
    "F16": torch.float16,
    "BF16": torch.bfloat16,
    "F32": torch.float32,
}


class SafetensorsCkptLoader(converter_base.CkptLoaderBase):
  """CkptLoader implementation for loading the Safetensors."""

  _HEAD_BYTES = 8

  def __init__(
      self,
      ckpt_path: str,
      is_symmetric: bool,
      attention_quant_bits: int,
      feedforward_quant_bits: int,
      embedding_quant_bits: int,
      special_model: str,
  ):
    """Initializes the loader.

    Args:
      ckpt_path: The filepath to the safetensors file.
      is_symmetric: Whether to apply symmetric or asymmetric quantization.
      attention_quant_bits: An integer that specify the target quantization bits
        (support 8 or 4) for the attention layers.
      feedforward_quant_bits: An integer that specify the target quantization
        bits (support 8 or 4) for the feedforward layers in each Transformer
        blocks.
      embedding_quant_bits: An integer that specify the target quantization bits
        (support 8 or 4) for the embedding (and the final projection) layers.
      special_model: A string that indicates which input model is and whether
        any special treatment is needed.
    """
    super().__init__(
        ckpt_path,
        is_symmetric,
        attention_quant_bits,
        feedforward_quant_bits,
        embedding_quant_bits,
    )

    self._special_model = special_model
    if special_model in ["STABLELM_4E1T_3B"]:
      self.mapper = StablelmMapper(
          is_symmetric,
          attention_quant_bits,
          feedforward_quant_bits,
          embedding_quant_bits,
      )
    elif special_model in ["PHI_2"]:
      self.mapper = PhiMapper(
          is_symmetric,
          attention_quant_bits,
          feedforward_quant_bits,
          embedding_quant_bits,
      )
    else:
      raise ValueError(f"Unknown special model: {special_model}")

    self._ckpt_path = ckpt_path
    if not os.path.exists(self._ckpt_path):
      raise ValueError(f"{self._ckpt_path} does not exists.")
    with open(self._ckpt_path, "rb") as f:
      head_bytes = f.read(self._HEAD_BYTES)
      metadata_bytes_num = np.frombuffer(head_bytes, dtype=np.uint64)[0]
      metadata_bytes = f.read(metadata_bytes_num)
      self.layers_info = json.loads(metadata_bytes)
      self.metadata_bytes_num = metadata_bytes_num

  def load_to_actions(self) -> List[converter_base.QuantizationAction]:
    tensor_names = self.layers_info.keys()
    actions = []
    for tensor_name in tensor_names:
      if tensor_name == "__metadata__":
        continue
      action = self.mapper.map_to_actions(tensor_name)
      if action is None:
        continue
      action.tensor_value = self._read_tensor_as_numpy(tensor_name)
      actions.append(action)
    return actions

  def _read_tensor_as_numpy(self, tensor_name) -> np.ndarray:
    """Reads a tensor from the model file as a numpy array with np.float32 type."""
    tensor_info = self.layers_info[tensor_name]
    with open(self._ckpt_path, "rb") as f:
      shape = tensor_info["shape"]
      dtype = tensor_info["dtype"]
      if dtype not in DTYPE_MAP:
        raise ValueError(f"{dtype} is not supported.")
      data_offsets = tensor_info["data_offsets"]
      f.seek(int(self._HEAD_BYTES + self.metadata_bytes_num + data_offsets[0]))
      tensor_bytes = f.read(data_offsets[1] - data_offsets[0])
      raw_tensor = torch.frombuffer(
          array.array("b", tensor_bytes), dtype=DTYPE_MAP[dtype]
      ).reshape(shape)
      return raw_tensor.float().t().contiguous().numpy()
