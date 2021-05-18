OUTPUT_DIR=./js
DEFAULT_EXPORTS:='_malloc','_free', \
				'_WebAvcCreateX264Encoder', '_WebAvcDestroyX264Encoder', '_WebAvcEncodeX264', \
				'_WebAvcCreateH264Decoder', '_WebAvcDestroyH264Decoder', '_WebAvcH264DecodeToResolution', '_WebAvcH264GetFrameResolution'

LIBOPUS_DIR=./opus
LIBOPUS_OBJ=$(LIBOPUS_DIR)/.libs/libopus.a
LIBOPUS_ENCODER_EXPORTS:='_opus_encoder_create','_opus_encode_float','_opus_encoder_ctl'
LIBOPUS_DECODER_EXPORTS:='_opus_decoder_create','_opus_decode_float','_opus_decoder_destroy'

LIBSPEEXDSP_DIR=./speexdsp
LIBSPEEXDSP_OBJ=$(LIBSPEEXDSP_DIR)/libspeexdsp/.libs/libspeexdsp.a
LIBSPEEXDSP_EXPORTS:='_speex_resampler_init','_speex_resampler_process_interleaved_float','_speex_resampler_destroy'

LIBX264_DIR=./x264
LIBX264_OBJ=$(LIBX264_DIR)/libx264.a

COMMON_FILTERS = scale crop overlay
COMMON_DECODERS = h264

LIBFFMPEG_DIR=./ffmpeg
LIBFFMPEG_OBJ=$(LIBFFMPEG_DIR)/ffmpeg.bc
FFMPEG_COMMON_ARGS = \
	--cc=emcc \
	--ranlib=emranlib \
	--enable-cross-compile \
	--target-os=none \
	--arch=x86 \
	--disable-runtime-cpudetect \
	--disable-asm \
	--disable-fast-unaligned \
	--disable-pthreads \
	--disable-w32threads \
	--disable-os2threads \
	--disable-debug \
	--disable-stripping \
	--disable-safe-bitstream-reader \
	--disable-all \
	--enable-ffmpeg \
	--enable-avcodec \
	--enable-avformat \
	--enable-avfilter \
	--enable-swresample \
	--enable-swscale \
	--disable-network \
	--disable-d3d11va \
	--disable-dxva2 \
	--disable-vaapi \
	--disable-vdpau \
	$(addprefix --enable-decoder=,$(COMMON_DECODERS)) \
	--enable-protocol=file \
	$(addprefix --enable-filter=,$(COMMON_FILTERS)) \
	--disable-bzlib \
	--disable-iconv \
	--disable-libxcb \
	--disable-lzma \
	--disable-sdl2 \
	--disable-securetransport \
	--disable-xlib \
	--disable-zlib

EMCC_OPTS=-O3 \
	-s EXPORTED_RUNTIME_METHODS="[cwrap, getValue, setValue]" \
	-s FILESYSTEM=0 -s MODULARIZE=1 -s EXPORT_NAME=webavc \
	-s EXPORTED_FUNCTIONS="[$(DEFAULT_EXPORTS),$(LIBOPUS_DECODER_EXPORTS),$(LIBOPUS_ENCODER_EXPORTS),$(LIBSPEEXDSP_EXPORTS)]"

WEBASM=$(OUTPUT_DIR)/webavc.js
WEBASM_MIN=$(OUTPUT_DIR)/webavc.min.js

default: $(WEBASM) $(WEBASM_MIN)

clean:
	rm -rf $(OUTPUT_DIR) $(LIBOPUS_DIR) $(LIBSPEEXDSP_DIR) $(LIBX264_DIR) $(LIBFFMPEG_DIR)

$(LIBOPUS_DIR)/autogen.sh $(LIBSPEEXDSP_DIR)/autogen.sh $(LIBX264_DIR)/configure:
	git submodule update --init

$(LIBOPUS_OBJ): $(LIBOPUS_DIR)/autogen.sh
	cd $(LIBOPUS_DIR); ./autogen.sh
	cd $(LIBOPUS_DIR); emconfigure ./configure --disable-extra-programs --disable-doc --disable-intrinsics --disable-rtcd --disable-stack-protector
	cd $(LIBOPUS_DIR); emmake make

$(LIBSPEEXDSP_OBJ): $(LIBSPEEXDSP_DIR)/autogen.sh
	cd $(LIBSPEEXDSP_DIR); ./autogen.sh
	cd $(LIBSPEEXDSP_DIR); emconfigure ./configure --disable-examples --disable-neon
	cd $(LIBSPEEXDSP_DIR); emmake make

$(LIBX264_OBJ): $(LIBX264_DIR)/configure
	cd $(LIBX264_DIR); emconfigure ./configure --host=i686-gnu --enable-static --disable-cli --disable-asm --bit-depth=8 --disable-thread --enable-pic
	cd $(LIBX264_DIR); emmake make

$(LIBFFMPEG_OBJ): $(LIBFFMPEG_DIR)/configure
	cd $(LIBFFMPEG_DIR) && \
	emconfigure ./configure \
		$(FFMPEG_COMMON_ARGS) \
		&& \
	emmake make -j && \
	cp ffmpeg ffmpeg.bc

$(WEBASM): $(LIBOPUS_OBJ) $(LIBSPEEXDSP_OBJ) $(LIBX264_OBJ) $(LIBFFMPEG_OBJ)
	mkdir -p $(OUTPUT_DIR)
	emcc -o $@ -g3 $(EMCC_OPTS) wrapper/x264_wrapper.c wrapper/ffmpeg_wrapper.cpp -I$(LIBFFMPEG_DIR) $(LIBOPUS_OBJ) $(LIBSPEEXDSP_OBJ) $(LIBX264_OBJ) $(LIBFFMPEG_DIR)/libavcodec/libavcodec.a $(LIBFFMPEG_DIR)/libavutil/libavutil.a

$(WEBASM_MIN): $(LIBOPUS_OBJ) $(LIBSPEEXDSP_OBJ) $(LIBX264_OBJ) $(LIBFFMPEG_OBJ)
	mkdir -p $(OUTPUT_DIR)
	emcc -o $@ --closure 1 $(EMCC_OPTS) wrapper/x264_wrapper.c wrapper/ffmpeg_wrapper.cpp -I$(LIBFFMPEG_DIR) $(LIBOPUS_OBJ) $(LIBSPEEXDSP_OBJ) $(LIBX264_OBJ) $(LIBFFMPEG_DIR)/libavcodec/libavcodec.a $(LIBFFMPEG_DIR)/libavutil/libavutil.a
