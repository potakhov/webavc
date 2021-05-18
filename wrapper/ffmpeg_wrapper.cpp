#include <cstdlib>
#include <mutex>
#include <unordered_map>
#include <memory>
#include "wrappers.h"

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

int WebAvcDestroyH264Decoder(int id) {
    std::lock_guard<std::mutex> lk(decoders_lock);

    auto it = decoders.find(id);
    if (it == decoders.end())
        return 0;

    if (it->second->ctx_ptr != NULL) {
        avcodec_close(it->second->ctx_ptr);
        av_free(it->second->ctx_ptr);
    }

    if (it->second->frame != NULL) {
        av_frame_free(&it->second->frame);
    }

    decoders.erase(it);
    return 1;
}

int WebAvcH264GetFrameResolution(int id, int* out_width, int* out_height) {
    std::lock_guard<std::mutex> lk(decoders_lock);

    auto it = decoders.find(id);
    if (it == decoders.end())
        return 0;

    if (it->second->size_available) {
        *out_width = it->second->width;
        *out_height = it->second->height;
        return 1;
    }

    return 0;
}

void stride_memcpy(uint8_t* d, uint8_t* s, int width, int height, int dstStride, int srcStride) {
    if (dstStride == srcStride && width == dstStride)
        memcpy(d, s, srcStride * height);
    else {
        for (int i = 0; i < height; i++) {
            memcpy(d, s, width);
            s += srcStride;
            d += dstStride;
        }
    }
}

void copyFrame(unsigned char* out_pic_buf, uint8_t** pData, int* iStride, int iWidth, int iHeight, bool flipUV) {
    stride_memcpy(
        out_pic_buf,
        pData[0],
        iWidth, iHeight,
        iWidth,
        iStride[0]); // Y

    if (!flipUV) {
        stride_memcpy(
            out_pic_buf + (iWidth * iHeight),
            pData[1],
            iWidth / 2, iHeight / 2,
            iWidth / 2,
            iStride[1]); // U

        stride_memcpy(
            out_pic_buf + (iWidth * iHeight) + (iWidth * iHeight / 4),
            pData[2],
            iWidth / 2, iHeight / 2,
            iWidth / 2,
            iStride[2]); // V
    }
    else {
        stride_memcpy(
            out_pic_buf + (iWidth * iHeight),
            pData[2],
            iWidth / 2, iHeight / 2,
            iWidth / 2,
            iStride[1]); // U

        stride_memcpy(
            out_pic_buf + (iWidth * iHeight) + (iWidth * iHeight / 4),
            pData[1],
            iWidth / 2, iHeight / 2,
            iWidth / 2,
            iStride[2]); // V
    }
}

void copyCropFrame(unsigned char* out_pic_buf, uint8_t** pData, int* iStride, int src_w, int src_h, int dst_w, int dst_h, bool flipUV) {
    int offset_src;
    int offset_dst;
    int width;

    if (src_w == dst_w) {
        offset_src = offset_dst = 0;
        width = dst_w;
    }
    else if (src_w < dst_w) {
        offset_src = 0;
        offset_dst = (dst_w - src_w) / 2;
        width = src_w;
    }
    else {
        offset_src = (src_w - dst_w) / 2;
        offset_dst = 0;
        width = dst_w;
    }

    unsigned char* y_src = pData[0];
    unsigned char* y_dst = out_pic_buf;
    unsigned char* u_src = pData[1];
    unsigned char* u_dst = y_dst + (dst_w * dst_h);
    unsigned char* v_src = pData[2];
    unsigned char* v_dst = u_dst + (dst_w * dst_h / 4);

    int height;

    if (src_h == dst_h) {
        height = dst_h;
    }
    else if (src_h < dst_h) {
        height = src_h;
        y_dst += dst_w * ((dst_h - src_h) / 2);
        u_dst += dst_w * ((dst_h - src_h) / 2) / 4;
        v_dst += dst_w * ((dst_h - src_h) / 2) / 4;
    }
    else {
        height = dst_h;
        y_src += iStride[0] * ((src_h - dst_h) / 2);
        u_src += iStride[1] * ((src_h - dst_h) / 2) / 2;
        v_src += iStride[2] * ((src_h - dst_h) / 2) / 2;
    }

    for (int y = 0; y < height; y++) {
        memcpy(y_dst + offset_dst, y_src + offset_src, width);
        y_dst += dst_w; y_src += iStride[0];

        if (!(y % 2)) {
            if (flipUV) {
                memcpy(v_dst + offset_dst / 2, u_src + offset_src / 2, width / 2);
                memcpy(u_dst + offset_dst / 2, v_src + offset_src / 2, width / 2);
            }
            else {
                memcpy(u_dst + offset_dst / 2, u_src + offset_src / 2, width / 2);
                memcpy(v_dst + offset_dst / 2, v_src + offset_src / 2, width / 2);
            }

            u_dst += dst_w / 2; u_src += iStride[1];
            v_dst += dst_w / 2; v_src += iStride[2];
        }
    }
}

void DoDecodeFrame(std::shared_ptr<decoder_instance> inst, const unsigned char* encoded_bitstream, int encoded_size, unsigned char* out_pic_buf, int out_pic_size, int dst_w, int dst_h) {
    AVPacket packet = { 0 };
    packet.data = (uint8_t*)encoded_bitstream;
    packet.size = encoded_size;

    inst->frame_available = false;
    inst->decoded_key_frame = false;

    int res;

    res = avcodec_send_packet(inst->ctx_ptr, &packet);
    if (res < 0)
        return;

    while (res >= 0) {
        res = avcodec_receive_frame(inst->ctx_ptr, inst->frame);

        if (!inst->size_available) {
            if (res == 0 || res == AVERROR(EAGAIN) || res == AVERROR_EOF) {
                inst->size_available = true;
                inst->width = inst->ctx_ptr->width;
                inst->height = inst->ctx_ptr->height;
            }
        }

        if (res < 0 || res == AVERROR(EAGAIN) || res == AVERROR_EOF)
            return;

        inst->frame_available = true;
        if (inst->frame->key_frame) {
            inst->decoded_key_frame = true;
        }

        if (out_pic_buf != nullptr) {
            if ((dst_w == 0 && dst_h == 0) || (dst_w == inst->ctx_ptr->width && dst_h == inst->ctx_ptr->height)) {
                if (out_pic_size >= inst->ctx_ptr->width * inst->ctx_ptr->height * 3 / 2)
                    copyFrame(out_pic_buf, inst->frame->data, inst->frame->linesize, inst->ctx_ptr->width, inst->ctx_ptr->height, false);
            }
            else {
                if (out_pic_size >= dst_w * dst_h * 3 / 2)
                    copyCropFrame(out_pic_buf, inst->frame->data, inst->frame->linesize, inst->ctx_ptr->width, inst->ctx_ptr->height, dst_w, dst_h, false);
            }
        }
    }
}

int WebAvcH264DecodeToResolution(int id, const unsigned char* encoded_bitstream, int encoded_size, unsigned char* out_pic_buf, int out_pic_size, int dst_w, int dst_h, int* decoded_frame_type) {
    std::lock_guard<std::mutex> lk(decoders_lock);

    auto it = decoders.find(id);
    if (it == decoders.end())
        return 0;

    DoDecodeFrame(it->second, encoded_bitstream, encoded_size, out_pic_buf, out_pic_size, dst_w, dst_h);

    if (it->second->frame_available) {
        if (it->second->decoded_key_frame)
            *decoded_frame_type = AVC_FRAME_I;
        else
            *decoded_frame_type = AVC_FRAME_P;

        return 1;
    }

    return 0;
}

}
