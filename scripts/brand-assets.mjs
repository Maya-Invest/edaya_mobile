// Rasterize supplied outlines; no logo reconstruction. Requires sharp 0.35.4 in the asset toolchain.
import fs from 'node:fs/promises';
import path from 'node:path';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
const sharp=createRequire(process.env.EDAYA_ASSET_TOOLCHAIN || import.meta.url)('sharp');
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const logos=path.join(root,'packages/edaya_shared/design-system/logos');
const out=path.join(root,'packages/edaya_shared/assets/brand');
for (const name of ['vertical-couleur','horizontal-couleur','symbole-couleur','vertical-blanc','horizontal-blanc','symbole-blanc']) {
 await sharp(path.join(logos,`edaya-${name}.svg`),{density:300}).resize({width:name.startsWith('horizontal')?1024:512}).png().toFile(path.join(out,`edaya-${name}.png`));
}
async function icon(file,size,symbol,bg,ratio) {
 const symbolData=await sharp(path.join(logos,`edaya-symbole-${symbol}.svg`),{density:400}).resize({width:Math.round(size*ratio),height:Math.round(size*ratio),fit:'inside'}).png().toBuffer();
 await fs.mkdir(path.dirname(file),{recursive:true});
 let output=sharp({create:{width:size,height:size,channels:4,background:bg}}).composite([{input:symbolData,gravity:'centre'}]);
 if(bg !== '#00000000') output=output.removeAlpha();
 await output.png().toFile(file);
}
async function walk(dir){let out=[];for(const d of await fs.readdir(dir,{withFileTypes:true})){if(['build','.dart_tool','.git'].includes(d.name))continue;let p=path.join(dir,d.name);out.push(...(d.isDirectory()?await walk(p):[p]));}return out;}
for(const app of ['guardian','teacher']) {
 const dir=path.join(root,'apps',app), symbol=app==='guardian'?'couleur':'blanc', bg=app==='guardian'?'#FFFFFF':'#2563EB';
 await icon(path.join(root,'branding/icons',`${app}.png`),1024,symbol,bg,.60);
 await icon(path.join(root,'branding/icons',`${app}-foreground.png`),1024,symbol,'#00000000',.43);
 for(const file of await walk(dir)) {
  if(file.includes('/build/')||file.includes('/.dart_tool/'))continue;
  if(/\/(mipmap-[^/]+\/ic_launcher|AppIcon.appiconset\/Icon-App[^/]*|web\/(?:icons\/Icon[^/]*|favicon))\.png$/.test(file)){
   const {width}=await sharp(file).metadata(); await icon(file,width,symbol,bg,file.includes('maskable')?.56:.60);
  }
  if(/drawable-[^/]+\/ic_launcher_foreground\.png$/.test(file)){
   const {width}=await sharp(file).metadata();await icon(file,width,symbol,'#00000000',.43);
  }
 }
 for(const [suffix,scale] of [['',1],['@2x',2],['@3x',3]])await icon(path.join(dir,`ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage${suffix}.png`),144*scale,symbol,'#00000000',2/3);
 await icon(path.join(dir,'android/app/src/main/res/drawable-mdpi/edaya_launch.png'),144,symbol,'#00000000',.43);
}
