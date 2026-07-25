# AI on Kubernetes — Güvenlik Demoları

> "AI with Containers: How Do AI and GPU Workloads Run on Kubernetes?" konuşması
> için canlı demo kiti. **Cloud Native Ankara.** Güvenlik bakış açısıyla.

İki zorunlu demo **tamamen local** çalışır (kind + Docker, **GPU gerektirmez**,
CPU yeterli) ve hafif **Ollama** modelleri kullanır. Bir de gerçek GPU isteyen
bonus vardır.

## İçindekiler

| Klasör | Demo | Güvenlik teması |
|--------|------|-----------------|
| `demo1-supply-chain-hardening/` | **Truva modeli + pod sertleştirme** | Supply chain (image + model), runtime hardening — OWASP LLM03 |
| `demo2-prompt-injection-exfil/`  | **Prompt injection → veri sızıntısı, NetworkPolicy ile durdurma** | Prompt injection, veri ifşası, egress izolasyonu — OWASP LLM01/LLM02 |
| `bonus-gpu-vram-residue/` | (opsiyonel, gerçek GPU) time-slicing izolasyon eksikliği | GPU multi-tenant izolasyonu (MIG vs time-slicing) |
| `cluster/` | kind + Calico kurulumu, NetworkPolicy smoke-test | Altyapı |

## Ön koşullar

- **Docker** (kind bunun üzerinde çalışır)
- **kind** (Kubernetes-in-Docker) — https://kind.sigs.k8s.io
- **kubectl**
- **python3** (Demo 1 Act 2 için; cluster'sız da çalışır)
- İsteğe bağlı: **trivy** (image tarama), `pip install safetensors numpy` (safetensors demosu)
- İnternet: sadece kurulum sırasında (image'lar + hafif model çekilir). Demo
  akışının kendisi offline çalışır — Demo 2'nin olayı zaten egress'i kesmek.

RAM önerisi: ~8 GB. Modeller: `qwen2.5:0.5b` (Demo 1), `llama3.2:1b` (Demo 2).

## Hızlı başlangıç

```bash
# 0) Cluster + Calico (NetworkPolicy'yi uygulayan CNI)
cd cluster
./setup-kind.sh
./verify-netpol.sh          # 'ENFORCED ✅' görmelisiniz — Demo 2'nin ön koşulu
cd ..

# 1) Demo 1 — supply chain + hardening
cd demo1-supply-chain-hardening
./run-demo1.sh
cd ..

# 2) Demo 2 — prompt injection -> exfil -> NetworkPolicy
cd demo2-prompt-injection-exfil
./setup-demo2.sh
# ikinci terminal: kubectl -n attacker logs -f deploy/listener
./run-demo2-vulnerable.sh   # exfil BAŞARILI 💥
./run-demo2-defended.sh     # exfil ENGELLENDİ ✅
cd ..

# Temizlik
cd cluster && ./teardown.sh
```

Ya da `make setup && make demo1 && make demo2 && make clean`.

## Neden bu iki demo "tam konu içinde"?

Konuşma "AI/GPU workload'ları K8s'te nasıl çalışır" ekseninde. İki demo bu
akışın en kritik güvenlik kırılganlıklarını **canlı** gösteriyor:

1. **Nasıl paketlenip dağıtılıyor?** → image + model artifact = tedarik zinciri.
   Bir modeli *yüklemek* bile kod çalıştırabilir (Demo 1). Serving pod'ları
   çoğunlukla privileged çalışır; sertleştirme reçetesi GPU'da da aynıdır.
2. **Nasıl servis edilip tüketiliyor?** → serving API + agent + ağ. LLM
   kandırıldığında pod'un ambient authority'si (mount'lu secret) sızıntıya
   dönüşür; K8s egress NetworkPolicy bunu kontrol altına alır (Demo 2).

GPU'ya özgü izolasyon (time-slicing vs MIG, VRAM residue, Kata/gVisor) sunumda
işlenir ve bonus script ile pekiştirilir; ilkeler (izolasyon, least-privilege,
egress kontrolü) CPU demolarıyla birebir aynıdır.

## Sahne güvenliği ipuçları

- Her şeyi **konuşmadan önce** kurun ve modelleri çekin (egress kesilince model
  çekilemez).
- `cluster/verify-netpol.sh` yeşilse Demo 2 punchline'ı çalışır.
- Küçük modeller olasılıksaldır: enjeksiyon uymazsa 1-2 kez tekrar gönderin veya
  `MODEL=qwen2.5:1.5b`. Agent asla uydurmaz; uymayınca dürüstçe raporlar.
- Saldırgan terminalini (`listener` logları) ekranın köşesinde açık tutun; secret
  oraya düşünce etki net görünür.

## Sorumluluk reddi

Tüm payload'lar **zararsızdır** (reverse shell yerine bir dosyaya yazar / log basar).
Sadece kendi local cluster'ınızda, eğitim amacıyla çalıştırın.
