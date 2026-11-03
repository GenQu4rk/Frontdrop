#include <metal_stdlib>
using namespace metal;
struct Uniforms { float2 resolution; float time; int scene; };
struct VertexOut { float4 position [[position]]; float2 uv; };
vertex VertexOut fullscreen(uint id [[vertex_id]]) {
    float2 p = float2((id << 1) & 2, id & 2);
    return { float4(p * 2.0 - 1.0, 0, 1), float2(p.x, 1.0-p.y) };
}
float hash21(float2 p) { return fract(sin(dot(p,float2(127.1,311.7)))*43758.5453); }
float noise(float2 p) {
    float2 i=floor(p), f=fract(p); f=f*f*(3.-2.*f);
    return mix(mix(hash21(i),hash21(i+float2(1,0)),f.x),mix(hash21(i+float2(0,1)),hash21(i+1),f.x),f.y);
}
float fbm(float2 p) {
    float v=0.,a=.5;
    for(int i=0;i<4;i++) { v+=a*noise(p); p=p*2.03+13.7; a*=.5; }
    return v;
}
float stars(float2 uv, float t) {
    float2 p=uv*float2(280,180), g=floor(p), f=fract(p)-.5;
    float h=hash21(g);
    return smoothstep(.045,0.,length(f))*step(.987,h)*(.55+.45*sin(t*.4+h*99.));
}
fragment float4 wallpaper(VertexOut in [[stage_in]], constant Uniforms &u [[buffer(0)]], texture2d<float> art [[texture(0)]]) {
    float2 uv=in.uv, p=(uv-.5)*float2(u.resolution.x/u.resolution.y,1.);
    float t=u.time;
    float3 c=0;
    if(u.scene>=6) {
        constexpr sampler s(address::clamp_to_edge,filter::linear);
        float2 q=(uv-.5)*.955+.5+float2(sin(t*.022)*.012,cos(t*.017)*.007);
        float imageAspect=float(art.get_width())/float(art.get_height());
        float screenAspect=u.resolution.x/u.resolution.y;
        if(screenAspect>imageAspect) q.y=(q.y-.5)*imageAspect/screenAspect+.5;
        else q.x=(q.x-.5)*screenAspect/imageAspect+.5;
        if(u.scene==6 && uv.y>.51) {
            float k=smoothstep(.51,.88,uv.y);
            q.x+=sin(uv.y*175.+t*.72)*.00085*k;
            q.y+=sin(uv.x*110.+uv.y*75.+t*.55)*.0005*k;
        }
        c=art.sample(s,q).rgb;
        if(u.scene==6) {
            float fog=fbm(float2(uv.x*5.+t*.012,uv.y*6.))*exp(-pow((uv.y-.53)*14.,2.));
            c=mix(c,float3(.66,.77,.81),fog*.10);
        } else {
            float2 cell=uv*float2(19,11)+float2(t*.025,-t*.035);
            float2 g=floor(cell), f=fract(cell)-.5;
            float mote=smoothstep(.026,0.,length(f))*step(.90,hash21(g));
            c+=float3(.95,.65,.30)*mote*(.4+.3*sin(t+hash21(g)*60.));
        }
    } else if(u.scene==0) {
        c=mix(float3(.008,.018,.055),float3(.025,.065,.11),uv.y);
        for(int i=0;i<4;i++) {
            float z=float(i), x=uv.x*3.5+z*1.7;
            float y=.39+.1*sin(x*1.4+t*.055+z)+.055*sin(x*3.2-t*.07);
            float beam=exp(-abs(uv.y-y)*(12.+z*4.));
            float fold=.35+.65*pow(noise(float2(x*7.+t*.05,z+uv.y*.9)),2.);
            c+=beam*fold*mix(float3(.055,.66,.38),float3(.36,.13,.60),float(i)/3.)*.8;
        }
        c+=stars(uv,t);
        float mountain=.85+.045*sin(uv.x*11.)+.03*sin(uv.x*24.+2.);
        c=mix(c,float3(.008,.018,.025),smoothstep(mountain-.003,mountain+.003,uv.y));
    } else if(u.scene==1) {
        float2 q=p*2.;
        float n=fbm(q+float2(t*.045,-t*.025));
        float f=sin(q.x*2.+q.y*3.+n*5.+t*.16);
        float fold=pow(.5+.5*f,2.5);
        c=mix(float3(.025,.035,.095),float3(.40,.23,.55),fold);
        c=mix(c,float3(.40,.69,.76),pow(.5+.5*sin(q.x*3.-q.y*2.+n*4.+t*.11),12.)*.65);
        c+=float3(.67,.46,.39)*pow(.5+.5*f,32.)*.7;
    } else if(u.scene==2) {
        float n=fbm(float2(p.x*4.,p.y*8.)+float2(t*.025,t*.055));
        float wave=sin(p.y*52.+n*8.+t*.38)+sin(p.x*22.-p.y*32.+t*.25);
        c=mix(float3(.008,.037,.08),float3(.03,.21,.28),n);
        c+=float3(.14,.48,.53)*pow(max(0.,wave*.5),10.)*.32;
        c+=float3(.25,.39,.40)*exp(-length(p-float2(.3,-.2))*3.)*.35;
    } else if(u.scene==3) {
        float2 q=p-float2(.12,-.05);
        float a=atan2(q.y,q.x), r=length(q);
        float nebula=fbm(q*3.+float2(t*.012,0));
        c=float3(.016,.016,.045)+float3(.12,.055,.22)*nebula*nebula;
        float ring=exp(-pow((r-.245)*80.,2.));
        c+=ring*float3(.8,.43,.21)*(1.+.5*sin(a*3.+t*.09));
        float disk=exp(-abs(q.y)*48.)*exp(-abs(q.x)*1.8)*smoothstep(.19,.25,r);
        c+=disk*float3(.55,.24,.10);
        c*=smoothstep(.205,.23,r);
        c+=stars(uv+float2(t*.0004,0),t)*smoothstep(.23,.25,r);
    } else if(u.scene==4) {
        float n=fbm(p*2.5+float2(t*.015,0));
        float wave=sin(p.y*10.+p.x*3.+n*4.+t*.08);
        c=mix(float3(.16,.07,.11),float3(.72,.36,.25),wave*.5+.5);
        c+=float3(.34,.25,.13)*pow(wave*.5+.5,14.);
        c*=.8+.2*sin(p.x*2.+p.y*1.5);
    } else {
        c=mix(float3(.035,.008,.07),float3(.22,.035,.19),exp(-abs(uv.y-.48)*5.));
        float sun=1.-smoothstep(.105,.108,length(float2(p.x,p.y+.095)));
        float stripes=smoothstep(.1,.3,sin(uv.y*190.));
        c+=sun*float3(.85,.27,.28)*mix(1.,stripes,smoothstep(.32,.54,uv.y));
        if(uv.y>.55) {
            float depth=1./max(.03,uv.y-.52);
            float gx=abs(fract(p.x*depth*2.)-.5);
            float gy=abs(fract(depth*.65+t*.20)-.5);
            float grid=1.-smoothstep(.012,.04,min(gx,gy));
            c=mix(float3(.013,.012,.04),float3(.23,.13,.49),grid*(uv.y-.5)*1.5);
        }
        c+=stars(uv,t)*step(uv.y,.43)*.7;
    }
    float vignette=1.-.17*dot(uv-.5,uv-.5);
    return float4(clamp(c*vignette,0.,1.),1);
}
