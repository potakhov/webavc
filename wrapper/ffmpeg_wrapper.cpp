#include <cstdlib>
#include <mutex>
#include <unordered_map>
#include <memory>

extern "C" {
    #include <libavcodec/avcodec.h>
}

struct decoder_instance {
    const AVCodec* dec_ptr;
    AVCodecContext* ctx_ptr;
    AVFrame* frame;

    int width;
    int height;

    bool frame_available;
    bool size_available;
    bool decoded_key_frame;
};

std::mutex decoders_lock;
std::unordered_map<int, std::shared_ptr<decoder_instance>> decoders;
int next_decoder_module = 1;

extern "C" {

int WebAvcCreateH264Decoder() {
    std::lock_guard<std::mutex> lk(decoders_lock);

    auto di = std::make_shared<decoder_instance>();
    di->dec_ptr = avcodec_find_decoder(AV_CODEC_ID_H264);
    if (di->dec_ptr == NULL) {
        return 0;
    }

    di->ctx_ptr = avcodec_alloc_context3(di->dec_ptr);
    if (di->ctx_ptr == NULL) {
        return 0;
    }

    di->frame = av_frame_alloc();
    if (di->frame == NULL) {
        return 0;
    }

    AVDictionary* codec_options(0);

    di->width = 0;
    di->height = 0;
    di->frame_available = false;
    di->size_available = false;
    di->decoded_key_frame = false;

    int res = avcodec_open2(di->ctx_ptr, di->dec_ptr, &codec_options);
    if (res != 0) {
        return 0;
    }

    decoders.insert(std::make_pair(next_decoder_module, di));
    return next_decoder_module++;
}

}
