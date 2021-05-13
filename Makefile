OUTPUT_DIR=./dist
OUTPUT_DIR_UNMINIFIED=./unminified
EMCC_OPTS=-O3 --closure 1 --memory-init-file 0 \
	-s FILESYSTEM=0 -s MODULARIZE=1 -s EXPORT_NAME=webavc
EMCC_WASM_OPTS=
EMCC_ASMJS_OPTS=-s WASM=0
DEFAULT_EXPORTS:='_malloc','_free'

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

WHOLE_BUNDLE_MIN=$(OUTPUT_DIR)/webavc.min.js
WHOLE_BUNDLE_ASMJS_MIN=$(OUTPUT_DIR)/webavc.min.asm.js
WHOLE_BUNDLE=$(OUTPUT_DIR_UNMINIFIED)/webavc.js
WHOLE_BUNDLE_ASMJS=$(OUTPUT_DIR_UNMINIFIED)/webavc.asm.js

default: $(WHOLE_BUNDLE) $(WHOLE_BUNDLE_MIN)

clean:
	rm -rf $(OUTPUT_DIR) $(OUTPUT_DIR_UNMINIFIED) $(LIBOPUS_DIR) $(LIBSPEEXDSP_DIR) $(LIBX264_DIR)
	mkdir $(OUTPUT_DIR)
	mkdir $(OUTPUT_DIR_UNMINIFIED)

$(LIBOPUS_DIR)/autogen.sh $(LIBSPEEXDSP_DIR)/autogen.sh:
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
	cd $(LIBX264_DIR); emconfigure ./configure --host=i686-gnu --enable-static --disable-cli --disable-asm --extra-cflags=-fPIC
	cd $(LIBX264_DIR); emmake make

$(WHOLE_BUNDLE): $(WHOLE_BUNDLE_ASMJS) $(LIBOPUS_OBJ) $(LIBSPEEXDSP_OBJ) $(LIBX264_OBJ)
	emcc -o $@ $(EMCC_OPTS) $(EMCC_WASM_OPTS) -g3 -s EXPORTED_FUNCTIONS="[$(DEFAULT_EXPORTS),$(LIBOPUS_DECODER_EXPORTS),$(LIBOPUS_ENCODER_EXPORTS),$(LIBSPEEXDSP_EXPORTS),$(LIBX264_EXPORTS)]" $(LIBOPUS_OBJ) $(LIBSPEEXDSP_OBJ) $(LIBX264_OBJ)

$(WHOLE_BUNDLE_ASMJS): $(WHOLE_BUNDLE_ASMJS_MIN) $(LIBOPUS_OBJ) $(LIBSPEEXDSP_OBJ) $(LIBX264_OBJ)
	emcc -o $@ $(EMCC_OPTS) $(EMCC_ASMJS_OPTS) -g3 -s EXPORTED_FUNCTIONS="[$(DEFAULT_EXPORTS),$(LIBOPUS_DECODER_EXPORTS),$(LIBOPUS_ENCODER_EXPORTS),$(LIBSPEEXDSP_EXPORTS),$(LIBX264_EXPORTS)]" $(LIBOPUS_OBJ) $(LIBSPEEXDSP_OBJ) $(LIBX264_OBJ)

$(WHOLE_BUNDLE_MIN): $(LIBOPUS_OBJ) $(LIBSPEEXDSP_OBJ) $(LIBX264_OBJ)
	emcc -o $@ $(EMCC_OPTS) $(EMCC_WASM_OPTS) -s EXPORTED_FUNCTIONS="[$(DEFAULT_EXPORTS),$(LIBOPUS_DECODER_EXPORTS),$(LIBOPUS_ENCODER_EXPORTS),$(LIBSPEEXDSP_EXPORTS),$(LIBX264_EXPORTS)]" $(LIBOPUS_OBJ) $(LIBSPEEXDSP_OBJ) $(LIBX264_OBJ)

$(WHOLE_BUNDLE_ASMJS_MIN): $(LIBOPUS_OBJ) $(LIBSPEEXDSP_OBJ) $(LIBX264_OBJ)
	emcc -o $@ $(EMCC_OPTS) $(EMCC_ASMJS_OPTS) -s EXPORTED_FUNCTIONS="[$(DEFAULT_EXPORTS),$(LIBOPUS_DECODER_EXPORTS),$(LIBOPUS_ENCODER_EXPORTS),$(LIBSPEEXDSP_EXPORTS),$(LIBX264_EXPORTS)]" $(LIBOPUS_OBJ) $(LIBSPEEXDSP_OBJ) $(LIBX264_OBJ)
