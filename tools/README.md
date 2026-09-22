# Ferramentas do tema (não vão no ZIP)

```
cd tools && npm install
node build-runtime.js          # gera theme/assets/js/go-ads-runtime.min.js e .lean.js
node build-runtime.js --check  # falha se as cópias geradas estiverem desatualizadas
```

Edite apenas `theme/assets/js/go-ads-runtime.js`. O build recusa qualquer `<` seguido de letra no
JavaScript gerado, porque plugins que reescrevem o HTML (ex.: Burst Statistics) corrompem scripts
inline que contenham `<body`, `<img` etc.
