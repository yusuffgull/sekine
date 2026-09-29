#!/usr/bin/env python3
"""Diyanet (ezanvakti.emushaf.net) vs Aladhan method=13 farkı, seçili diaspora şehirleri.
Yeni ülke eklerken / mevsim değişince tekrar çalıştır; sonucu docs/decisions.md ve
Sekine/Core/PrayerTimes/ApproxCalendar.swift (ApproxSafetyMargin) ile karşılaştır. Rate-limit için yavaştır."""
import json,urllib.request,time,re,collections
B="https://ezanvakti.emushaf.net"
def g(u,tries=6):
    for k in range(tries):
        try: return json.load(urllib.request.urlopen(urllib.request.Request(u,headers={'User-Agent':'Mozilla/5.0'}),timeout=30))
        except Exception as e:
            if k==tries-1: raise
            time.sleep(8*(k+1))
T=[("11",["BRUKSEL","BRUSSELS"],50.85,4.35),("49",["ZURIH","ZURICH"],47.37,8.54),("26",["KOPENHAG","COPENHAGEN"],55.68,12.57),
("33",["NEW YORK"],40.71,-74.0),("5",["BAKU","BAKÜ"],40.41,49.87),("12",["STOCKHOLM","STOKHOLM"],59.33,18.07),("52",["TORONTO"],43.65,-79.38),("59",["SYDNEY","SIDNEY"],-33.87,151.21)]
for ulke,keys,lat,lon in T:
    f=None
    for s in g(f"{B}/sehirler/{ulke}"):
        for i in g(f"{B}/ilceler/{s['SehirID']}"):
            n=(i['IlceAdiEn']+' '+i['IlceAdi']).upper()
            if any(k in n for k in keys): f=i;break
        if f:break
    if not f: print(ulke,"district not found");continue
    v=g(f"{B}/vakitler/{f['IlceID']}")
    year=int(v[0]['MiladiTarihKisa'][-4:])
    al=g(f"https://api.aladhan.com/v1/calendar?latitude={lat}&longitude={lon}&method=13&annual=true&year={year}")['data']
    am={x['date']['gregorian']['date']:x['timings'] for d in al.values() for x in d}
    diffs=collections.defaultdict(list)
    for r in v:
        dd=r['MiladiTarihKisa'].replace('.','-')
        if dd not in am: continue
        for dk,ak in [('Imsak','Fajr'),('Gunes','Sunrise'),('Ogle','Dhuhr'),('Ikindi','Asr'),('Aksam','Maghrib'),('Yatsi','Isha')]:
            a=re.match(r'(\d+):(\d+)',am[dd][ak]); b=re.match(r'(\d+):(\d+)',r[dk])
            diffs[dk].append(int(a[1])*60+int(a[2])-int(b[1])*60-int(b[2]))
    print(f"{f['IlceAdiEn']:<12}({ulke}) {v[0]['MiladiTarihUzunIso8601'][-6:]} "+"  ".join(f"{k}:{min(x)}..{max(x)}" for k,x in diffs.items()),flush=True)
    time.sleep(10)
