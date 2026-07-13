# Jarvis Vision Model Decision

Decision date: 2026-07-12

Release decision: **D. NVIDIA candidates are rejected for this release.** The primary detector is Apple's Core ML `YOLOv3TinyInt8LUT` artifact. The detector boundary remains model-agnostic so a future native Core ML detector can be evaluated without replacing capture, tracking, narration, or accessibility code.

This is a device and release decision, not a judgment about the quality of NVIDIA's server and Jetson products. An iPhone XR has an A12 Bionic and no NVIDIA GPU. Jarvis Vision must run offline through Core ML and Vision without CUDA, TensorRT, DeepStream, Triton, Jetson, or a remote inference service.

## Acceptance result

| Candidate | Intended deployment | Classes or vocabulary | Source format | Core ML conversion path | Redistribution terms | Approximate source size | Unsupported operations or runtime | Fixture inference | XR suitability | Decision |
| --- | --- | --- | --- | --- | --- | ---: | --- | --- | --- | --- |
| NVIDIA TAO Grounding DINO | TAO training and TensorRT deployment on NVIDIA GPUs | Open vocabulary | PyTorch checkpoint; deployable ONNX | No proven path. Current Core ML Tools expects TensorFlow or a PyTorch `TorchScript`/`ExportedProgram`, not TAO's deployable ONNX | NVIDIA Open Model License obligations | 688.39 MB deployable; 1.93 GB trainable | Official deployment converts ONNX to TensorRT; tokenizer remains outside the graph | NVIDIA/TensorRT only | Not plausible for A12 live use | Reject |
| NVIDIA TAO DINO | TAO, DeepStream, TensorRT | 80 COCO classes | PyTorch checkpoint to ONNX | No pinned PyTorch reconstruction and no Core ML compile/load proof; standard export still ends at ONNX | CC BY-NC-SA 4.0 for the inspected pretrained package | 199.58 MB for ResNet-50 deployable | Default export can use a TensorRT DMHA plugin; NVIDIA runtime is the documented target | None on Core ML | Too large and no native path | Reject |
| NVIDIA TAO RT-DETR Warehouse | Warehouse perception through TAO/DeepStream/TensorRT | Seven warehouse-specific classes | ONNX | No current supported direct ONNX to Core ML path and no traceable source object supplied with the deployable package | NVIDIA Open Model License obligations | 250.52 MB | Official inference uses TensorRT on Linux/NVIDIA hardware | None on Core ML | Narrow vocabulary and no native path | Reject |
| NVIDIA PeopleNet 2.3.4 | People analytics through TAO/DeepStream/TensorRT | Person, bag, face | Decrypted INT8 ONNX | No supported current direct ONNX conversion and no candidate-specific PyTorch reconstruction | NVIDIA Open Model License obligations | 8.38 MB | NVIDIA documents NVIDIA GPU plus TAO/DeepStream/TensorRT; GridBox output needs additional clustering/NMS | None on Core ML | Size is plausible, but runtime and three-class coverage fail the gate | Reject; closest near-miss |
| NVIDIA PeopleNet Transformer 1.1 | People analytics through DeepStream/TensorRT | Person, bag, face | Deformable-DETR ONNX | No supported current direct ONNX path or Core ML load proof | Model-card licensing points to NVIDIA terms that are not an unambiguous drop-in redistribution grant for this repository | 179.25 MB compressed package | TensorRT-tested NVIDIA deployment only | None on Core ML | Narrow and too large | Reject |
| NVIDIA NanoOWL / OWL-ViT B/32 | Real-time open-vocabulary detection on Jetson Orin | Text prompts | PyTorch/Safetensors to ONNX to TensorRT engine | NanoOWL's implementation explicitly builds and loads a CUDA TensorRT engine, not Core ML | NanoOWL code Apache-2.0; checkpoint Apache-2.0 | About 613 MB for one weight representation | CUDA, TensorRT, `torch2trt`, Jetson-oriented engine | NVIDIA runtime example only | Direct hard failure | Reject |
| TAO YOLOv4-tiny CSPDarknet-tiny | Feature-extractor initialization for TAO retraining | No detector classes until retrained | HDF5 feature-extractor weights | The published artifact is not a detector; a conversion would not produce usable boxes or classes | CC BY 4.0 | 28.57 MB | Retraining required; legacy deployment uses TensorRT plugins | Impossible with the downloaded artifact alone | Incomplete model | Reject |

Sizes are upstream package or source sizes, not compiled Core ML sizes. No rejected model was downloaded or converted. Each met an explicit hard-fail condition before conversion, so the truthful result is **not attempted after authoritative hard failure**, not “conversion failed.”

## Evidence and commands

Authoritative evidence:

- [NVIDIA TAO Deploy overview](https://docs.nvidia.com/tao/tao-toolkit/latest/text/tao_deploy/tao_deploy_overview.html) states that TAO checkpoints export to ONNX and deploy through TensorRT.
- [TAO Grounding DINO deployment](https://docs.nvidia.com/tao/tao-toolkit/latest/text/tao_deploy/grounding_dino.html) builds a TensorRT engine from ONNX.
- [TAO DINO export](https://docs.nvidia.com/tao/tao-toolkit/latest/text/cv_finetuning/pytorch/object_detection/dino.html) documents ONNX export and the TensorRT plugin path.
- [TAO RT-DETR](https://docs.nvidia.com/tao/tao-toolkit/latest/text/cv_finetuning/pytorch/object_detection/rt_detr.html) documents ONNX/TensorRT deployment.
- [PeopleNet model card](https://catalog.ngc.nvidia.com/orgs/nvidia/tao/models/peoplenet/-) documents its three classes, NVIDIA deployment, limitations, and model license.
- [PeopleNet Transformer model card](https://catalog.ngc.nvidia.com/orgs/nvidia/tao/models/peoplenet_transformer/-) documents three classes and a 179.25 MB compressed package.
- [NanoOWL](https://github.com/NVIDIA-AI-IOT/nanoowl) explicitly targets Jetson Orin with TensorRT and builds a hardware-specific engine.
- [Apple Core ML Tools supported formats](https://apple.github.io/coremltools/docs-guides/source/target-conversion-formats.html) documents current TensorFlow and PyTorch inputs.
- [Apple Core ML Tools FAQ](https://apple.github.io/coremltools/docs-guides/source/faqs.html) states that the old ONNX converter is frozen and unmaintained.

The following NGC metadata commands were identified but intentionally not executed because the authoritative runtime evidence had already failed the gate. They are retained for a future server/Jetson evaluation:

```text
ngc registry model info "nvidia/tao/grounding_dino:grounding_dino_swin_tiny_commercial_deployable_v1.0" --format_type json
ngc registry model info "nvidia/tao/pretrained_dino_coco:dino_resnet_50_deployable_v1.0" --format_type json
ngc registry model info "nvidia/tao/rtdetr_2d_warehouse:deployable_rn50_v1.0.2" --format_type json
ngc registry model info "nvidia/tao/peoplenet:pruned_quantized_decrypted_v2.3.4" --format_type json
ngc registry model info "nvidia/tao/peoplenet_transformer:deployable_v1.1" --format_type json
```

## Selected production detector

`YOLOv3TinyInt8LUT.mlmodel` is distributed by Apple as a native Core ML model for multiple-object detection. The build downloads it from Apple's model host, verifies the exact bytes, then lets Xcode compile it into the application bundle.

- Download size: `8,913,366` bytes
- SHA-256: `cde8af2528d6eca1d1580fdd0f0147cb6613d40ba962656b5f683c65f571870e`
- Input: RGB image, 416 by 416
- Additional inputs: confidence and intersection-over-union thresholds
- Output: normalized center-x, center-y, width, height coordinates plus confidence values after nonmaximum suppression
- Vocabulary: 80 embedded COCO labels
- Runtime: Core ML and Vision, fully on device after installation
- Known unsupported targets: doors, stairs, curbs, crosswalks, and exit signs as trackable detector classes

The selected model is much smaller than the transformer candidates, already has a verified Core ML schema, requires no conversion project, and is compatible with the repository's reproducible unsigned-IPA build. Real iPhone XR latency and sustained thermal behavior still require physical-device measurement.

## User impact

The decision favors a detector that can actually be packaged, loaded, fixture-tested, and run privately on the target phone. Open-vocabulary search would be useful, but it is not useful enough to justify an NVIDIA server, a hidden network dependency, or an unverified A12 transformer port. Unsupported targets are reported honestly, and the model-independent protocol leaves room for a future compact Core ML detector that passes the same acceptance gate.
