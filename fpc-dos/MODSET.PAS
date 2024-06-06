  modinit;
  mix := 7000;   {use 5050 for fast gaming }
  pro := 0; {Leave at 0}
  loop :=4; {0 means mod will play anD stop}
  dev:=7;
  modvolume (255,255,255,255);    { Full volume }
  md:='planetx.mod';
  loop:=4;
  modsetup ( stat, dev, mix, pro, loop, md );
