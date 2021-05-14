OUTPUT_DIR=./js
DEFAULT_EXPORTS:='_malloc','_free','_WebAvcGetVersion', '_WebAvcCreateX264Encoder', '_WebAvcDestroyX264Encoder'

LIBOPUS_DIR=./opus
LIBOPUS_OBJ=$(LIBOPUS_DIR)/.libs/libopus.a
LIBOPUS_ENCODER_EXPORTS:='_opus_encoder_create','_opus_encode_float','_opus_encoder_ctl'
LIBOPUS_DECODER_EXPORTS:='_opus_decoder_create','_opus_decode_float','_opus_decoder_destroy'

LIBSPEEXDSP_DIR=./speexdsp
LIBSPEEXDSP_OBJ=$(LIBSPEEXDSP_DIR)/libspeexdsp/.libs/libspeexdsp.a
LIBSPEEXDSP_EXPORTS:='_speex_resampler_init','_speex_resampler_process_interleaved_float','_speex_resampler_destroy'

LIBX264_DIR=./x264
LIBX264_OBJ=$(LIBX264_DIR)/libx264.a
LIBX264_EXPORTS:='_x264_encoder_encode'

#-s INITIAL_MEMORY=2146435072 ?

EMCC_OPTS=-O3 \
	-s EXPORTED_RUNTIME_METHODS="[cwrap, getValue, setValue]" \
	-s FILESYSTEM=0 -s MODULARIZE=1 -s EXPORT_NAME=webavc \
	-s EXPORTED_FUNCTIONS="[$(DEFAULT_EXPORTS),$(LIBOPUS_DECODER_EXPORTS),$(LIBOPUS_ENCODER_EXPORTS),$(LIBSPEEXDSP_EXPORTS),$(LIBX264_EXPORTS)]"

WEBASM=$(OUTPUT_DIR)/webavc.js
WEBASM_MIN=$(OUTPUT_DIR)/webavc.min.js

default: $(WEBASM) $(WEBASM_MIN)

clean:
	rm -rf $(OUTPUT_DIR) $(LIBOPUS_DIR) $(LIBSPEEXDSP_DIR) $(LIBX264_DIR)

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

$(WEBASM): $(LIBOPUS_OBJ) $(LIBSPEEXDSP_OBJ) $(LIBX264_OBJ)
	mkdir -p $(OUTPUT_DIR)
	emcc -o $@ -g3 $(EMCC_OPTS) wrapper/wrapper.c $(LIBOPUS_OBJ) $(LIBSPEEXDSP_OBJ) $(LIBX264_OBJ)

$(WEBASM_MIN): $(LIBOPUS_OBJ) $(LIBSPEEXDSP_OBJ) $(LIBX264_OBJ)
	mkdir -p $(OUTPUT_DIR)
	emcc -o $@ --closure 1 $(EMCC_OPTS) wrapper/wrapper.c $(LIBOPUS_OBJ) $(LIBSPEEXDSP_OBJ) $(LIBX264_OBJ)
