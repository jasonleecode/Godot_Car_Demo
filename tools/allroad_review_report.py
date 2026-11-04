"""Build a self-contained local before/after report from Godot review captures.
Run tests/AllroadVisualReview.gd -- --baseline before changing the asset, then
run it normally after importing the new GLB. No image pixels are altered here.
"""
import base64
import json
from pathlib import Path

ROOT = Path('/tmp')
VIEWS = [
    ('front', '前侧', '核对机盖下落、格栅高度、灯眉和保险杠转角。'),
    ('side', '侧面', '核对前后悬、窗柱位置、车顶长度和后窗倾角。'),
    ('rear', '后侧', '核对后窗贴合、包角尾灯、尾门凹槽和下护板。'),
    ('front-ortho', '正前', '正交投影：比较宽高关系、灯组对称性和格栅比例。'),
    ('side-ortho', '正侧', '正交投影：比较轮心与车身轮廓，排除透视影响。'),
    ('rear-ortho', '正后', '正交投影：比较后窗、尾灯、牌照与尾门的层次。'),
    ('front-right', '另一侧', '检查镜像侧的法线、窗柱和灯组，避免只修好一侧。'),
]

def data(path):
    mime = 'image/png' if path.suffix == '.png' else 'image/jpeg'
    return 'data:' + mime + ';base64,' + base64.b64encode(path.read_bytes()).decode()

views = []
for key, title, note in VIEWS:
    views.append(dict(key=key, title=title, note=note,
                      before=data(ROOT / f'allroad-audit-before-{key}.png'),
                      after=data(ROOT / f'allroad-review-{key}.png')))
refs = []
for file, caption, url in [
    ('allroad-reference-846.jpg', '实车前侧 · AUDI AG / A196846', 'https://www.audi.com/en/images/detail/audi-a6-allroad-quattro-78931'),
    ('allroad-reference-848.jpg', '实车后侧 · AUDI AG / A196848', 'https://www.audi.com/en/images/detail/audi-a6-allroad-quattro-78933'),
    ('allroad-blueprint.png', '官方尺寸图 · C8 A6 allroad', 'https://media.audi.com/is/content/audi/global/assets/dimensions/a6/A6_allroad_2020_dimensions_1.pdf'),
]:
    if (ROOT / file).exists():
        refs.append(dict(image=data(ROOT / file), caption=caption, url=url))
html = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>A6 allroad · 多角度外观复核</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#edf0ed;color:#203b37;font-family:system-ui,sans-serif}
main{max-width:1280px;margin:auto;padding:36px 24px}h1{margin:6px 0 12px;font-size:32px}p{line-height:1.7}
.kicker{font-size:12px;letter-spacing:2px;color:#5d756c}nav{display:flex;flex-wrap:wrap;gap:8px;margin:22px 0 14px}
button{border:1px solid #b6c2bc;border-radius:8px;background:white;padding:10px 20px;color:inherit;font:inherit;cursor:pointer}
button[aria-selected=true]{background:#244d43;color:white;border-color:#244d43}
.compare{position:relative;aspect-ratio:16/9;overflow:hidden;background:#82939e;border-radius:12px}
.compare img{position:absolute;inset:0;width:100%;height:100%;object-fit:contain}
#before{clip-path:inset(0 50% 0 0)}#divider{position:absolute;left:50%;top:0;bottom:0;width:2px;background:white;pointer-events:none}
.label{position:absolute;top:16px;background:#183b34de;color:white;padding:6px 12px;border-radius:6px;font-size:13px}
.old{left:16px}.new{right:16px}.slider{display:flex;gap:16px;align-items:center;margin:16px 0}input{flex:1;accent-color:#326f5d}
#note{min-height:30px;color:#52695f}article{background:white;border:1px solid #d6ded8;border-radius:12px;padding:18px 22px;margin-top:18px}
.reference img{width:100%;display:block;border-radius:8px}.references{display:grid;gap:20px}a{color:#246b58}summary{cursor:pointer;font-size:19px;padding:10px 0}small{color:#5f7068}
</style><main><div class="kicker">C8 / A6 ALLROAD · 2026-11-04</div>
<h1>从七个角度检查车身</h1>
<p>拖动滑块对照同机位画面：左侧为修改前，右侧为本轮修改后。照片与尺寸图用于核对整体轮廓，不能用驾驶测试代替外观判断。</p>
<nav id="views" aria-label="观察角度"></nav>
<div class="compare"><img id="after" alt="修改后车模"><img id="before" alt="修改前车模"><div id="divider"></div><span class="label old">修改前</span><span class="label new">修改后</span></div>
<label class="slider">修改前 <input id="range" type="range" min="0" max="100" value="50" aria-label="修改前后对照位置"> 修改后</label><p id="note"></p>
<article><strong>本轮修正</strong><p>按照官方 2925 mm 轴距、921 mm 前悬和 1105 mm 后悬重新定位车身；降低机盖前缘，缩短车顶并增加后窗倾角；重做环绕包围、灯框、尾门凹槽和轮拱内衬。碰撞体同步贴合新轮廓。</p><small>这仍是程序化游戏模型，控制曲面并非原厂 CAD，轮毂、灯具光学结构和内饰仍有简化。未把参考照片用作车身贴图。</small></article>
<article><details><summary>展开官方参考照片与尺寸图</summary><div id="references" class="references"></div></details></article>
</main><script>
const views=__VIEWS__, refs=__REFS__;
const before=document.getElementById('before'),after=document.getElementById('after'),range=document.getElementById('range');
function select(i){before.src=views[i].before;after.src=views[i].after;document.getElementById('note').textContent=views[i].note;document.querySelectorAll('nav button').forEach((b,j)=>b.setAttribute('aria-selected',String(i===j)));}
views.forEach((v,i)=>{const b=document.createElement('button');b.textContent=v.title;b.onclick=()=>select(i);document.getElementById('views').append(b)});
range.oninput=()=>{before.style.clipPath=`inset(0 ${100-range.value}% 0 0)`;document.getElementById('divider').style.left=range.value+'%'};
refs.forEach(r=>{const fig=document.createElement('figure');fig.className='reference';const img=document.createElement('img');img.src=r.image;img.alt=r.caption;img.loading='lazy';const link=document.createElement('a');link.href=r.url;link.textContent=r.caption;link.target='_blank';link.rel='noopener';fig.append(img,link);document.getElementById('references').append(fig)});select(0);
</script></html>'''
html = html.replace('__VIEWS__', json.dumps(views, ensure_ascii=False)).replace('__REFS__', json.dumps(refs, ensure_ascii=False))
output = ROOT / 'allroad-comparison.html'
output.write_text(html)
print(f'{output} ({output.stat().st_size:,} bytes)')
