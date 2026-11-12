# Documentação

- `arquitetura.md`: diagrama da arquitetura (fase 9).
- `adr/`: decisões de arquitetura curtas, uma por arquivo (ADRs).

## Decisões já tomadas (viram ADRs ao longo das fases)

1. **k3s numa única EC2 em vez de EKS.** O plano de controle do EKS custa
   cerca de US$ 73/mês, mais do que a demo inteira precisa. O k3s é um
   Kubernetes certificado, então os manifests e o Helm chart são os mesmos.
2. **TF-IDF + regressão logística em vez de deep learning.** Treina em
   segundos na CPU, a imagem fica pequena e dá para explicar o modelo em
   um slide.
