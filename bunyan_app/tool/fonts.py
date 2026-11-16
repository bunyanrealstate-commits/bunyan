# بيطلع خط IBM Plex Sans Arabic (اللي في بنيان القديم) كـ TTF علشان التطبيق يستخدمه من غير نت
import re,base64,io,os,sys
from fontTools.ttLib import TTFont
src=sys.argv[1]; out=sys.argv[2]; os.makedirs(out,exist_ok=True)
s=open(src,encoding='utf-8').read()
for m in re.finditer(r"@font-face\{font-family:'IBM Plex Sans Arabic';font-weight:(\d+)[^}]*?base64,([A-Za-z0-9+/=]+)\)",s):
    f=TTFont(io.BytesIO(base64.b64decode(m.group(2)))); f.flavor=None; f.save(os.path.join(out,'PlexArabic-%s.ttf'%m.group(1))); print('font',m.group(1))
