"""Review-only public factual roster pilot. Stops on HTTP errors; no access bypass.
No biographies, photographs, proprietary ratings or legal license assertions are exported.
The output must be reviewed before use. Never writes the production game database.
"""
import json, re, time
from pathlib import Path
from urllib.parse import urljoin, urlparse
from concurrent.futures import ThreadPoolExecutor
import requests
from bs4 import BeautifulSoup

OUT=Path('roster-review'); OUT.mkdir(exist_ok=True)
S=requests.Session()
S.headers['User-Agent']='MaisUmaRodada development factual research/0.5.1'
ALLOWED={'www.palmeiras.com.br','www.fcbarcelona.com'}
def get(url):
    if urlparse(url).netloc not in ALLOWED: raise ValueError('Unexpected source host')
    r=S.get(url,timeout=35)
    r.raise_for_status()
    if urlparse(r.url).netloc not in ALLOWED: raise ValueError('Unexpected redirect host')
    return BeautifulSoup(r.content,'html.parser')

def profile(row):
    try:
        soup=get(row['source'])
        text=' '.join(soup.stripped_strings)
        row['page_title']=soup.title.get_text(' ',strip=True) if soup.title else ''
        # Keep only short, labelled factual fields, not the page prose.
        if row['club']=='palmeiras':
            m=re.search(r'Nome(?: completo)?\s*:?\s*(.{1,100}?)\s*(?:Data de nascimento|Nascimento)',text,re.I)
            if m: row['full_name']=m.group(1).strip()
            for key,pat in {
                'birth_text':r'(?:Data de nascimento|Nascimento)\s*:?\s*(\d{1,2}\s*(?:de\s*)?[A-Za-zÀ-ÿ]+\s*(?:de\s*)?\d{4}|\d{2}/\d{2}/\d{4})',
                'height_text':r'Altura\s*:?\s*(\d[.,]\d{2})',
                'birthplace_text':r'(?:Local de nascimento|Naturalidade)\s*:?\s*(.{1,70}?)(?=Altura|Peso|Posição|Data|Clube|Nacionalidade)',
            }.items():
                m=re.search(pat,text,re.I)
                if m: row[key]=m.group(1).strip()
        else:
            for key,label in [('birth_text','Date of birth'),('birthplace_text','Place of birth'),('height_text','Height'),('weight_text','Weight')]:
                m=re.search(re.escape(label)+r'\s*:?\s*(.{1,80}?)(?=Date of birth|Place of birth|Height|Weight|Club debut|Honours|Career|cm\b|kg\b)',text,re.I)
                if m: row[key]=m.group(1).strip()
            # Structured data is optional; never infer facts from missing fields.
            for node in soup.select('script[type="application/ld+json"]'):
                try:
                    value=json.loads(node.string or node.get_text())
                    nodes=value if isinstance(value,list) else [value]
                    for data in nodes:
                        if isinstance(data,dict) and data.get('@type')=='Person':
                            for field in ['name','birthDate','nationality','height','weight']:
                                if field in data: row['structured_'+field]=data[field]
                except (ValueError,TypeError): pass
        row['checked_on']='2026-09-29'
        row['status']='fetched'
    except Exception as error:
        row['status']='unavailable'; row['error']=str(error)[:160]
    return row

rows=[]
for club,url in [('palmeiras','https://www.palmeiras.com.br/elenco/'),('barcelona','https://www.fcbarcelona.com/en/football/first-team/players')]:
    try:
        soup=get(url)
        seen=set()
        for a in soup.select('a[href]'):
            href=urljoin(url,a['href'])
            label=a.get_text(' ',strip=True)
            accept=('/jogador/?jogador=' in href) if club=='palmeiras' else bool(re.search(r'/first-team/players/\d+/',href))
            if not accept or href in seen: continue
            seen.add(href)
            rows.append({'club':club,'roster_source':url,'label':label,'source':href})
    except Exception as e:
        (OUT/(club+'-error.txt')).write_text(str(e))
with ThreadPoolExecutor(max_workers=3) as pool:
    result=list(pool.map(profile,rows))
(OUT/'official-facts-pilot.json').write_text(json.dumps({'as_of':'2026-09-29','scope':'Two official club rosters, NOT all leagues','rights':'No license agreement obtained; facts only; no photos or proprietary ratings','players':result},ensure_ascii=False,indent=2))
print(json.dumps({'records':len(result),'fetched':sum(p['status']=='fetched' for p in result),'clubs':{c:sum(p['club']==c for p in result) for c in ['palmeiras','barcelona']}}))
