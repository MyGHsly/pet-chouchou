"""Package the exact validated Chuchu pet artwork and its useful sources."""

from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED


ROOT = Path("/Users/lingyu.shuai/Documents/Codex/2026-10-04/x")
OUTPUT = ROOT / "outputs/chuchu-final-pet-assets.zip"
V4 = ROOT / "work/chu_chu/update-v4"
TEMP = Path("/var/folders/dy/__ygy2cs18b5gmb90nmdmm580000gq/T")

files = {
    "final/spritesheet.png": ROOT / "outputs/chuchu-spritesheet-coat-corrected.png",
    "final/contact-sheet.png": ROOT / "outputs/chuchu-contact-sheet-coat-corrected.png",
    "final/look-directions.png": ROOT / "outputs/chuchu-directions-coat-corrected.png",
    "previews/all-states.gif": ROOT / "outputs/chuchu-all-states-coat-corrected.gif",
    "previews/running-left.gif": ROOT / "outputs/chuchu-running-left-coat-corrected.gif",
    "previews/running-right.gif": ROOT / "outputs/chuchu-running-right-coat-corrected.gif",
    "previews/look-loop.gif": ROOT / "outputs/chuchu-look-loop-coat-corrected.gif",
    "previews/still-idle.png": ROOT / "outputs/chuchu-still-idle-coat-corrected.png",
    "previews/still-running-right.png": ROOT / "outputs/chuchu-still-running-right-coat-corrected.png",
    "previews/still-jumping.png": ROOT / "outputs/chuchu-still-jumping-coat-corrected.png",
    "previews/still-waiting.png": ROOT / "outputs/chuchu-still-waiting-coat-corrected.png",
    "references/canonical-corrected.png": V4 / "references/canonical-corrected.png",
    "references/left-side.png": TEMP / "codex-clipboard-2e92a89a-31c2-4d38-94f1-4a75fb5a01f4.png",
    "references/right-side.jpg": TEMP / "codex-clipboard-a1a3b80e-11a4-4605-8cfa-ded9d0f51981.jpg",
    "references/tail-back.jpg": TEMP / "codex-clipboard-50825503-17a2-43af-b2da-7d0889698b99.jpg",
    "qa/atlas-validation.json": V4 / "final/validation.json",
    "qa/pet-quality.json": V4 / "qa/pet-quality.json",
    "qa/frame-review.json": V4 / "qa/frame-review.json",
}
for row in sorted((V4 / "decoded").glob("*.png")):
    files[f"source-rows/{row.name}"] = row

missing = [str(source) for source in files.values() if not source.is_file()]
if missing:
    raise SystemExit("Missing package inputs:\n" + "\n".join(missing))

readme = """丑丑 ChatGPT 宠物素材（最终版）

pet ID: pet_6ac26aeb3ccc81918ff7554fa9bce6ad
最终图集 SHA-256: f2bb8fcb165ec8c32afff8a6a8541bbfcdae2cf64790d7f5502aa87378dcb90b

final/spritesheet.png 是已通过官方校验并更新到当前宠物的完整动画图集。
previews/ 包含动作和视线预览；source-rows/ 是各动作的生成源图。
references/ 保存了本次修正花纹和尾巴所用的关键照片与主体参考图。
qa/ 保存图集结构、帧检查和质量校验记录。

动作：奔跑时两只后腿同步抬起；左右侧花纹分别参照不同照片；尾巴黑色尾根、白色外段。
"""

OUTPUT.parent.mkdir(parents=True, exist_ok=True)
with ZipFile(OUTPUT, "w", compression=ZIP_DEFLATED, compresslevel=6) as archive:
    archive.writestr("README.txt", readme)
    for archive_name, source in sorted(files.items()):
        archive.write(source, archive_name)

print(OUTPUT)
print(f"files: {len(files) + 1}")
print(f"bytes: {OUTPUT.stat().st_size}")
