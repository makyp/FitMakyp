"""Fotos de calentamiento/estiramientos desde Free Exercise DB (dominio público)."""
import sys
from pathlib import Path
from PIL import Image, ImageOps
src = Path(sys.argv[1]); out = Path(sys.argv[2]); out.mkdir(parents=True, exist_ok=True)
MAP = {
 'marcha':'Fast_Skipping','jacks_suaves':'Star_Jump','circulos_cadera':'Standing_Hip_Circles',
 'circulos_brazos':'Arm_Circles','abrazos':'Dynamic_Chest_Stretch','flexion_pared':'Incline_Push-Up',
 'gato_camello':'Cat_Stretch','balanceo_piernas':'Front_Leg_Raises','sentadilla_aire':'Bodyweight_Squat',
 'puente_activacion':'Butt_Lift_Bridge','dead_bug_suave':'Dead_Bug','est_cuadriceps':'On_Your_Side_Quad_Stretch',
 'est_isquios':'Seated_Floor_Hamstring_Stretch','est_gluteo':'Ankle_On_The_Knee','est_mariposa':'Groin_and_Back_Stretch',
 'est_gemelo':'Calf_Stretch_Hands_Against_Wall','est_pecho':'Elbows_Back','est_hombro':'Shoulder_Stretch',
 'est_triceps':'Triceps_Stretch','est_nino':'Childs_Pose','est_cobra':'Lower_Back_Curl',
}
for mine, theirs in MAP.items():
  d = next(p for p in (src/'cand'/theirs, src/'cand2'/theirs) if p.exists())
  for i, tag in ((0,'start'),(1,'end')):
    p = d/f'{i}.jpg'
    with Image.open(p) as im: im.verify()
    im = ImageOps.exif_transpose(Image.open(p)).convert('RGB')
    r = 360/im.height; im = im.resize((round(im.width*r),360), Image.LANCZOS)
    im.save(out/f'{mine}_{tag}.jpg', quality=82, optimize=True, progressive=True)
  print(mine)
