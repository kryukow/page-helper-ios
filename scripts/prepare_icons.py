"""Generate explicit legacy iPhone/iPad icon sizes with the macOS image tool."""
from pathlib import Path
import json,subprocess
folder=Path(__file__).resolve().parents[1]/'App/Assets.xcassets/AppIcon.appiconset'
images=[]
for idiom,sizes in [('iphone',[(20,[2,3]),(29,[2,3]),(40,[2,3]),(60,[2,3])]),('ipad',[(20,[1,2]),(29,[1,2]),(40,[1,2]),(76,[1,2]),(83.5,[2])])]:
 for size,scales in sizes:
  for scale in scales:
   pixels=int(size*scale);name=f'Icon-{idiom}-{pixels}.png'
   subprocess.run(['sips','-z',str(pixels),str(pixels),str(folder/'AppIcon.png'),'--out',str(folder/name)],check=True,stdout=subprocess.DEVNULL)
   images.append({'idiom':idiom,'size':f'{size}x{size}','scale':f'{scale}x','filename':name})
images.append({'idiom':'ios-marketing','size':'1024x1024','scale':'1x','filename':'AppIcon.png'})
(folder/'Contents.json').write_text(json.dumps({'images':images,'info':{'author':'xcode','version':1}},indent=2))
