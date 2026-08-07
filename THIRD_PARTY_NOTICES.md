# Third-Party Notices

Kiki can download and run third-party speech-recognition and speech-generation models entirely on the user's device.

## MLX Audio Swift and MLX Swift

Kiki uses [MLX Audio Swift](https://github.com/Blaizzy/mlx-audio-swift) and [MLX Swift](https://github.com/ml-explore/mlx-swift) for local Apple-silicon speech generation. Both projects are distributed under the MIT License.

## Qwen3-TTS

Kiki Voice Studio can download the `Qwen3-TTS-12Hz-0.6B-Base-8bit` model conversion from the MLX community. Qwen3-TTS is developed by the Qwen team at Alibaba Cloud and distributed under the Apache License 2.0.

- [Qwen3-TTS project and license](https://github.com/QwenLM/Qwen3-TTS)
- [Kiki's MLX model conversion](https://huggingface.co/mlx-community/Qwen3-TTS-12Hz-0.6B-Base-8bit)

## FluidAudio

Kiki uses [FluidAudio](https://github.com/FluidInference/FluidAudio), copyright the FluidAudio contributors, under the Apache License 2.0.

## NVIDIA Parakeet TDT

The Parakeet TDT v2 and v3 model weights are created by NVIDIA and distributed under the Creative Commons Attribution 4.0 International license (CC BY 4.0).

- [Parakeet TDT v2 model card](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v2)
- [Parakeet TDT v3 model card](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3)

Model conversions optimized for Core ML are downloaded through FluidAudio from the FluidInference model repositories.

## whisper.cpp and Whisper models

Kiki vendors [whisper.cpp](https://github.com/ggml-org/whisper.cpp), copyright Georgi Gerganov and contributors, under the MIT License. Whisper model weights are provided through the whisper.cpp model repository and remain subject to their applicable terms.

## Sparkle

Kiki uses [Sparkle](https://github.com/sparkle-project/Sparkle), copyright the Sparkle contributors, under its permissive license, for cryptographically signed application updates.
