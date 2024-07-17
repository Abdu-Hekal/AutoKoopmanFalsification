function czz=cz(alpha,beta,el)
% Body-axis Z Force
a=[.770 .241 -.100 -.415 -.731 -1.053 -1.355 -1.646 -1.917 -2.120 -2.248 -2.229]';
s=.2*alpha;
k=fix(s);
if(k<=-2),k=-1;end
if(k>=9),k=8;end
da=s-k;
l=k+fix(1.1*sign(da));
l=l+3;
k=k+3;
s=a(k)+abs(da)*(a(l)-a(k));
czz=s*(1-(beta/57.3)^2)-.19*(el/25);

end
