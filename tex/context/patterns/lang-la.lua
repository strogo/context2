return {
 ["comment"]="% generated by mtxrun --script pattern --convert",
 ["exceptions"]={
  ["n"]=0,
 },
 ["metadata"]={
  ["mnemonic"]="la",
  ["source"]="hyph-la",
  ["texcomment"]="% Latin Hyphenation Patterns\
% \
% (more info about the licence to be added later)\
% \
% This file is part of hyph-utf8 package and resulted from\
% semi-manual conversions of hyphenation patterns into UTF-8 in June 2008.\
%\
% Source: lahyph.tex (2007-09-03)\
% Author: Claudio Beccari <claudio.beccari at polito.it>\
%\
% The above mentioned file should become obsolete,\
% and the author of the original file should preferaby modify this file instead.\
%\
% Modificatios were needed in order to support native UTF-8 engines,\
% but functionality (hopefully) didn't change in any way, at least not intentionally.\
% This file is no longer stand-alone; at least for 8-bit engines\
% you probably want to use loadhyph-foo.tex (which will load this file) instead.\
%\
% Modifications were done by Jonathan Kew, Mojca Miklavec & Arthur Reutenauer\
% with help & support from:\
% - Karl Berry, who gave us free hands and all resources\
% - Taco Hoekwater, with useful macros\
% - Hans Hagen, who did the unicodifisation of patterns already long before\
%               and helped with testing, suggestions and bug reports\
% - Norbert Preining, who tested & integrated patterns into TeX Live\
%\
% However, the \"copyright/copyleft\" owner of patterns remains the original author.\
%\
% The copyright statement of this file is thus:\
%\
%    Do with this file whatever needs to be done in future for the sake of\
%    \"a better world\" as long as you respect the copyright of original file.\
%    If you're the original author of patterns or taking over a new revolution,\
%    plese remove all of the TUG comments & credits that we added here -\
%    you are the Queen / the King, we are only the servants.\
%\
% If you want to change this file, rather than uploading directly to CTAN,\
% we would be grateful if you could send it to us (http://tug.org/tex-hyphen)\
% or ask for credentials for SVN repository and commit it yourself;\
% we will then upload the whole \"package\" to CTAN.\
%\
% Before a new \"pattern-revolution\" starts,\
% please try to follow some guidelines if possible:\
%\
% - \\lccode is *forbidden*, and I really mean it\
% - all the patterns should be in UTF-8\
% - the only \"allowed\" TeX commands in this file are: \\patterns, \\hyphenation,\
%   and if you really cannot do without, also \\input and \\message\
% - in particular, please no \\catcode or \\lccode changes,\
%   they belong to loadhyph-foo.tex,\
%   and no \\lefthyphenmin and \\righthyphenmin,\
%   they have no influence here and belong elsewhere\
% - \\begingroup and/or \\endinput is not needed\
% - feel free to do whatever you want inside comments\
%\
% We know that TeX is extremely powerful, but give a stupid parser\
% at least a chance to read your patterns.\
%\
% For more unformation see\
%\
%    http://tug.org/tex-hyphen\
%\
%------------------------------------------------------------------------------\
%\
%                  ********** lahyph.tex *************\
%\
% Copyright 1999- 2001 Claudio Beccari\
%                [latin hyphenation patterns]\
%\
% -----------------------------------------------------------------\
% IMPORTANT NOTICE:\
%\
% This program can be redistributed and/or modified under the terms\
% of the LaTeX Project Public License Distributed from CTAN\
% archives in directory macros/latex/base/lppl.txt; either\
% version 1 of the License, or any later version.\
% -----------------------------------------------------------------\
%\
% Patterns for the latin language mainly in modern spelling\
% (u when u is needed and v when v is needed); medieval spelling\
% with the ligatures \\ae and \\oe  and the (uncial) lowercase `v'\
% written as a `u' is also supported; apparently there is no conflict\
% between the patterns of modern  Latin and those of medieval Latin.\
%\
% Support for font encoding OT1 with 128-character set and\
% for font encoding T1 with a 256-character set.\
%\
% Prepared by  Claudio Beccari\
%              Politecnico di Torino\
%              Torino, Italy\
%              e-mail beccari@polito.it\
%\
% 1999/03/10 Integration of `lahyph7.tex' and `lahyph8.tex' into\
% one file `lahyph.tex' supporting fonts in OT1 and T1 encoding by\
% Bernd Raichle using the macro code from `dehypht.tex' (this code\
% is Copyright 1993,1994,1998,1999 Bernd Raichle/DANTE e.V.).\
%\
% 2010/06/01 Removal of pattern 2'2 (probably a leftover from Italian)\
%\
% \\versionnumber{3.2}   \\versiondate{2010/06/01}\
%\
% Information after \\endinput.\
%\
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%\
%\
% \\message{Latin Hyphenation Patterns `lahyph' Version 3.2 <2010/06/01>}\
%\
%",
 },
 ["patterns"]={
  ["characters"]="abcdefghijklmnopqrstuvxzæœ",
  ["data"]=".a2b3l .anti1 .anti3m2n .circu2m1 .co2n1iun .di2s3cine .e2x1 .o2b3 .para1i .para1u .su2b3lu .su2b3r 2s3que. 2s3dem. 3p2sic 3p2neu æ1 œ1 a1ia a1ie a1io a1iu ae1a ae1o ae1u e1iu io1i o1ia o1ie o1io o1iu uo3u 1b 2bb 2bd b2l 2bm 2bn b2r 2bt 2bs 2b. 1c 2cc c2h2 c2l 2cm 2cn 2cq c2r 2cs 2ct 2cz 2c. 1d 2dd 2dg 2dm d2r 2ds 2dv 2d. 1f 2ff f2l 2fn f2r 2ft 2f. 1g 2gg 2gd 2gf g2l 2gm g2n g2r 2gs 2gv 2g. 1h 2hp 2ht 2h. 1j 1k 2kk k2h2 1l 2lb 2lc 2ld 2lf l3f2t 2lg 2lk 2ll 2lm 2ln 2lp 2lq 2lr 2ls 2lt 2lv 2l. 1m 2mm 2mb 2mp 2ml 2mn 2mq 2mr 2mv 2m. 1n 2nb 2nc 2nd 2nf 2ng 2nl 2nm 2nn 2np 2nq 2nr 2ns n2s3m n2s3f 2nt 2nv 2nx 2n. 1p p2h p2l 2pn 2pp p2r 2ps 2pt 2pz 2php 2pht 2p. 1qu2 1r 2rb 2rc 2rd 2rf 2rg r2h 2rl 2rm 2rn 2rp 2rq 2rr 2rs 2rt 2rv 2rz 2r. 1s2 2s3ph 2s3s 2stb 2stc 2std 2stf 2stg 2st3l 2stm 2stn 2stp 2stq 2sts 2stt 2stv 2s. 2st. 1t 2tb 2tc 2td 2tf 2tg t2h t2l t2r 2tm 2tn 2tp 2tq 2tt 2tv 2t. 1v v2l v2r 2vv 1x 2xt 2xx 2x. 1z 2z. a1ua a1ue a1ui a1uo a1uu e1ua e1ue e1ui e1uo e1uu i1ua i1ue i1ui i1uo i1uu o1ua o1ue o1ui o1uo o1uu u1ua u1ue u1ui u1uo u1uu a2l1ua a2l1ue a2l1ui a2l1uo a2l1uu e2l1ua e2l1ue e2l1ui e2l1uo e2l1uu i2l1ua i2l1ue i2l1ui i2l1uo i2l1uu o2l1ua o2l1ue o2l1ui o2l1uo o2l1uu u2l1ua u2l1ue u2l1ui u2l1uo u2l1uu a2m1ua a2m1ue a2m1ui a2m1uo a2m1uu e2m1ua e2m1ue e2m1ui e2m1uo e2m1uu i2m1ua i2m1ue i2m1ui i2m1uo i2m1uu o2m1ua o2m1ue o2m1ui o2m1uo o2m1uu u2m1ua u2m1ue u2m1ui u2m1uo u2m1uu a2n1ua a2n1ue a2n1ui a2n1uo a2n1uu e2n1ua e2n1ue e2n1ui e2n1uo e2n1uu i2n1ua i2n1ue i2n1ui i2n1uo i2n1uu o2n1ua o2n1ue o2n1ui o2n1uo o2n1uu u2n1ua u2n1ue u2n1ui u2n1uo u2n1uu a2r1ua a2r1ue a2r1ui a2r1uo a2r1uu e2r1ua e2r1ue e2r1ui e2r1uo e2r1uu i2r1ua i2r1ue i2r1ui i2r1uo i2r1uu o2r1ua o2r1ue o2r1ui o2r1uo o2r1uu u2r1ua u2r1ue u2r1ui u2r1uo u2r1uu",
  ["minhyphenmax"]=1,
  ["minhyphenmin"]=1,
  ["n"]=335,
 },
 ["version"]="1.001",
}