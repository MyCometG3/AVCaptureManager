## Appendix : Video style

#### Video style definition
|Video Style Name|Encode Pix.|Visible Pix.|Pix.Aspect|Type|
|:-----------|:-----------|:------------|:-:|:-:|
|SD_640_480_Full|640x480|640x480|1:1|SD525|
|SD_768_576_Full|768x576|768x576|1:1|SD625|
|HD_1920_1080_Full|1920x1080|1920x1080|1:1|HD1125|
|HD_1280_720_Full|1280x720|1280x720|1:1|HD750|
|SD_720_480_4_3|720x480|704x480|10:11|SD525|
|SD_720_480_16_9|720x480|704x480|40:33|SD525|
|SD_720_576_4_3|720x576|704x576|12:11|SD625|
|SD_720_576_16_9|720x576|704x576|16:11|SD625|
|HD_1920_1080_16_9|1920x1080|1888x1062|1:1|HD1125|
|HD_1280_720_16_9|1280x720|1248x702|1:1|HD750|
|SD_525_13_5MHz_4_3|720x486|704x480|10:11|SD525|
|SD_525_13_5MHz_16_9|720x486|704x480|40:33|SD525|
|SD_625_13_5MHz_4_3|720x576|702.92x576|59:54|SD625|
|SD_625_13_5MHz_16_9|720x576|702.92x576|118:81|SD625|
|HDV_HDCAM|1440x1080|1416x1062|4:3|HD1125|

#### ColorPrimaries/TransferFunction/YCbCrMatrix
|Source Type|ColorPrimaries|TransferFunction|YCbCrMatrix|
|:---|:-------------|:----------------|:------------|
|SD525/SMPTE-C|6: SMPTE_C|1: ITU_R_709_2|6: ITU_R_601_4|
|SD625/PAL|5: EBU_3213|1: ITU_R_709_2|6: ITU_R_601_4|
|HD750/HD1125/Rec.709|1: ITU_R_709_2|1: ITU_R_709_2|1: ITU_R_709_2|

#### Clean Aperture offset range:
|Video Style Name|Encode Pix.|Visible Pix.|Offset range|
|:-----------|:-----------|:------------|:-:|
|SD_640_480_Full|640x480|640x480|+-0, +-0|
|SD_768_576_Full|768x576|768x576|+-0, +-0|
|HD_1920_1080_Full|1920x1080|1920x1080|+-0, +-0|
|HD_1280_720_Full|1280x720|1280x720|+-0, +-0|
|SD_720_480_4_3|720x480|704x480|+-8, +-0|
|SD_720_480_16_9|720x480|704x480|+-8, +-0|
|SD_720_576_4_3|720x576|704x576|+-8, +-0|
|SD_720_576_16_9|720x576|704x576|+-8, +-0|
|HD_1920_1080_16_9|1920x1080|1888x1062|+-16, +-9|
|HD_1280_720_16_9|1280x720|1248x702|+-16:+-9|
|SD_525_13_5MHz_4_3|720x486|704x480|+-8:+-3|
|SD_525_13_5MHz_16_9|720x486|704x480|+-8:+-3|
|SD_625_13_5MHz_4_3|720x576|702.92x576|+-7:+-0|
|SD_625_13_5MHz_16_9|720x576|702.92x576|+-7:+-0|
|HDV_HDCAM|1440x1080|1416x1062|+-12:+-9|

###### NOTE: Sample configurations:
> SD (SMPTE-C)
>- Composite NTSC (SMPTE 170M-1994)
>- Digital 525 (SMPTE 125M-1995 (4:3 parallel)
>- SMPTE 267M-1995 (16:9 parallel)
>- SMPTE 259M-1997 (serial)

> SD (PAL)
>- Composite PAL (Rec. ITU-R BT. 470-4)
>- Digital 625 (Rec. ITU-R BT. 656-3)

> HD (Rec. 709)
>- 1920x1080 HDTV (SMPTE 274M-1995)
>- 1280x720 HDTV (SMPTE 296M-1997)

###### NOTE: Unsupported video sources type:
> Followings are not supported:
>- 1920x1035 HDTV (SMPTE 240M-1995, SMPTE 260M-1992)
>- 1920x1080 HDTV interim color implementation (SMPTE 274M-1995)
>
>These two use a combination of:
>- AVVideoColorPrimaries_SMPTE_C
>- AVVideoTransferFunction_SMPTE_240M_1995
>- AVVideoYCbCrMatrix_SMPTE_240M_1995

#### Technical Reference:
- TN2162 : Uncompressed Y´CbCr Video in QuickTime Files
(https://developer.apple.com/library/content/technotes/tn2162/_index.html)
- TN2227 : Video Color Management in AV Foundation and QTKit
(https://developer.apple.com/library/content/technotes/tn2227/_index.html)

Copyright © 2016年 MyCometG3. All rights reserved.
