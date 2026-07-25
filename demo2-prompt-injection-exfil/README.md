# Demo 2 — Prompt Injection → Veri Sızıntısı, NetworkPolicy ile Durdurma

**Güvenlik sorusu:** LLM'i kandırmak *kaçınılmaz* olabilir. Peki model
kandırıldığında bile veriyi pod'dan **dışarı çıkaramamasını** nasıl garanti
ederiz?

Bu, AI'a özgü bir saldırının (prompt injection) klasik bir Kubernetes
primitifiyle (egress NetworkPolicy) nasıl kontrol altına alındığını gösteren
uçtan uca bir senaryo. **Savunma katmanlı (defense in depth):** model katmanı
savunmaları ile altyapı katmanı savunmaları birlikte.

## Mimari

```
  belge ──► agent ──► Ollama (LLM) ──► model çıktısı
             │                            │
             │   çıktıda ACTION: EXFIL    │
             │   satırını arar    ◄───────┘
             │
             └─► bulursa: MOUNT EDİLMİŞ SECRET'ı okur ve <url>'e POST eder
```

- **agent** bir "confused deputy": mount edilmiş bir Secret'a (ambient authority)
  sahip ve ne yapacağına LLM çıktısı karar veriyor.
- **attacker** ayrı bir namespace'te; sızan veriyi yakalayan basit bir dinleyici.
- Kusur mimari — modelin "hatası" değil. OWASP **LLM01** (Prompt Injection) →
  **LLM02/LLM06** (hassas veri ifşası).

## Ön koşullar
- kind cluster + **Calico** (NetworkPolicy'yi *uygulayan* CNI). `../cluster/setup-kind.sh` bunu kurar.
- Sahneye çıkmadan önce mutlaka: `../cluster/verify-netpol.sh` → `ENFORCED ✅` görmelisiniz.
- Model: `llama3.2:1b` (küçük ama enjeksiyona uyumu yüksek). Alternatif: `qwen2.5:1.5b`.

## Kurulum (talkten önce bir kez)
```bash
./setup-demo2.sh                       # her şeyi kurar + modeli çeker
kubectl -n attacker logs -f deploy/listener   # ikinci terminalde saldırganın gelen kutusu
```

## Sahne akışı
```bash
# FAZ A — savunmasız
./run-demo2-vulnerable.sh
#   1) benign belge -> normal özet, hiçbir şey gönderilmez
#   2) zararlı belge -> model 'ACTION: EXFIL ...' üretir -> agent SECRET'ı sızdırır
#   => saldırgan terminalinde prod DB parolası belirir 💥

# FAZ B — savunmalı
./run-demo2-defended.sh
#   aynı zararlı belge tekrar gönderilir
#   model yine kanar, agent yine dener AMA egress engellenir => exfil=BLOCKED ✅
```

## Neden bu punchline güçlü?
- **Model yine kandırıldı.** Hiçbir şey değişmedi — enjeksiyon çalışıyor.
- Değişen tek şey **patlama yarıçapı**: `default-deny egress` sayesinde secret
  pod'u terk edemedi. Agent sadece DNS ve Ollama'ya çıkabiliyor; saldırganın
  dinleyicisine giden yol kapalı.
- Ders: prompt injection'ı %100 engelleyemeyebilirsiniz; ama **least-privilege
  egress + dar secret mount'ları** ile onu zararsız hale getirebilirsiniz.

## Manifest'lerdeki savunma noktaları
- `netpol/00-default-deny-egress.yaml` — kilit taşı; her pod için tüm egress kapalı.
- `netpol/10-allow-dns.yaml` — sadece DNS. (İsim çözmek ≠ bağlanabilmek.)
- `netpol/20-allow-ollama.yaml` — agent yalnızca Ollama'ya, sadece 11434'e çıkabilir.
- Ek sertleştirme: Secret'ı bu kadar geniş mount etmemek; egress'i tek tek allow'lamak;
  runtime'da (Falco/Tetragon) beklenmeyen giden bağlantıları alarma bağlamak.

## Determinizm notu (sahne güvenliği)
Küçük modeller olasılıksaldır. `llama3.2:1b` bu basit `ACTION:` formatında
enjeksiyona güvenilir şekilde uyar; yine de uymazsa agent dürüstçe "no tool
call — nothing sent" yazar (uydurmaz). Uymazsa 1-2 kez tekrar gönderin veya
`MODEL=qwen2.5:1.5b` kullanın. Ham model çıktısı log'lara basılır; izleyici
modelin gerçekten zararlı satırı ürettiğini görür.

## Temizlik
```bash
kubectl delete ns ai-demo attacker
```
