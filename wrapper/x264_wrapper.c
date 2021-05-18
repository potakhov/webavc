#include <stdint.h>
#include <string.h>
#include "../x264/x264.h"
#include "wrappers.h"

x264_t* enc_ptr = 0;
x264_picture_t pic_in;
x264_picture_t pic_out;
int w = 0;
int h = 0;

void fill_x264_param(x264_param_t* param, int width, int height, int framerate, int bitrate, int iframe_interval, int bframe_interval) {
    //if (x264_param_default_preset(param, "veryfast", "fastdecode,zerolatency") != 0)
    if (x264_param_default_preset(param, "ultrafast", "fastdecode,zerolatency") != 0)
        return;

    param->i_width = width;
    param->i_height = height;

    param->rc.i_vbv_buffer_size = bitrate / 2;
    param->rc.i_vbv_max_bitrate = bitrate;
    param->rc.i_rc_method = X264_RC_ABR;

    param->i_fps_num = framerate;
    param->i_fps_den = 1;
    param->rc.i_bitrate = bitrate;
    param->i_bframe = bframe_interval;
    param->i_bframe_adaptive = X264_B_ADAPT_NONE;
    param->b_interlaced = 0;
    param->b_repeat_headers = 1;
    param->b_aud = 0;
    param->i_sps_id = 0;
    param->b_vfr_input = 0;
    param->b_annexb = 1;
    if (iframe_interval == 0) {
        param->i_keyint_max = X264_KEYINT_MAX_INFINITE;
        param->i_keyint_min = X264_KEYINT_MIN_AUTO;
    }
    else {
        param->i_keyint_max = iframe_interval * 2;
        param->i_keyint_min = iframe_interval;
    }
    param->i_sync_lookahead = 0;
    param->i_scenecut_threshold = 0;
}

int encodePicIn(unsigned char* enc_buf, int* enc_type) {
    int i_nals;
    x264_nal_t* nalu;

    if (enc_type != 0 && *enc_type == AVC_FRAME_I) {
        pic_in.i_type = X264_TYPE_IDR;
    }
    else {
        pic_in.i_type = X264_TYPE_AUTO;
    }

    int len = x264_encoder_encode(enc_ptr, &nalu, &i_nals, &pic_in, &pic_out);
    if (len > 0) {
        if (enc_type != 0) {
            switch (pic_out.i_type) {
            case X264_TYPE_IDR: {
                *enc_type = AVC_FRAME_I;
            } break;
            case X264_TYPE_I: {
                *enc_type = AVC_FRAME_SI;
            } break;
            case X264_TYPE_P:
            case X264_TYPE_BREF: {
                *enc_type = AVC_FRAME_P;
            } break;
            case X264_TYPE_B: {
                *enc_type = AVC_FRAME_B;
            } break;
            default: {
                *enc_type = AVC_FRAME_UNKNOWN;
            } break;
            }
        }

        memcpy(enc_buf, nalu[0].p_payload, len);
    }

    return len;
}

int WebAvcDestroyX264Encoder() {
    if (enc_ptr == 0)
        return 0;
    
    x264_encoder_close(enc_ptr);
    enc_ptr = 0;
    w = 0;
    h = 0;

    return 1;
}

int WebAvcCreateX264Encoder(int width, int height, int framerate, int bitrate, int iframe_interval, int bframe_interval) {
    x264_param_t param;

    WebAvcDestroyX264Encoder();

    w = width;
    h = height;

    fill_x264_param(&param, width, height, framerate, bitrate, iframe_interval, bframe_interval);

    x264_picture_init(&pic_out);
    x264_picture_init(&pic_in);

    pic_in.img.i_csp = X264_CSP_I420;
    pic_in.img.i_plane = 3;
    pic_in.img.i_stride[0] = width;
    pic_in.img.i_stride[1] = width / 2;
    pic_in.img.i_stride[2] = width / 2;

    enc_ptr = x264_encoder_open(&param);

    if (enc_ptr != 0) {
		return iframe_interval;
	}

    return 0;
}

int WebAvcEncodeX264(const unsigned char* pic_buf, unsigned char* enc_buf, int* enc_type) {
    if (enc_ptr == 0)
        return 0;

	pic_in.img.plane[0] = (uint8_t*)(pic_buf);
	pic_in.img.plane[2] = (uint8_t*)(pic_buf + (w * h));
	pic_in.img.plane[1] = (uint8_t*)(pic_buf + (w * h) + (w * h / 4));

	return encodePicIn(enc_buf, enc_type);
}
