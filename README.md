# Souza & Cia. — AI Workforce

Uma agência multi-agente rodando 100% local, com dashboard ao vivo.
Sem chamadas pra OpenAI/Anthropic. Tudo no seu hardware.

## O que está no pacote

| Arquivo                          | O que é                                          |
|----------------------------------|--------------------------------------------------|
| `souza-agency-dashboard.html`    | Dashboard standalone (simulação visual)         |
| `souza_agency.py`                | Backend CrewAI + FastAPI + SSE com Ollama       |

## Stack alvo

Pensado pro teu setup:
- **HP EliteDesk G4-800** → control plane / FastAPI server
- **RTX 4070 Ti** → Ollama servindo `qwen2.5:14b`, `llama3.1:8b`, `mistral:7b`
- **MacBook Air M2** → cliente / dashboard no navegador
- (Os Raspberry Pis ficam de fora — agentes de LLM ainda são pesados pra ARM)

## Modo 1 — Só ver a UI rodando (sem backend)

Abre `souza-agency-dashboard.html` no navegador. O script de demo simula
4 agentes trabalhando num projeto real (estratégia de canal no YouTube
sobre IA local). Útil pra mostrar em entrevistas — você prova que entendeu
o pattern sem precisar do hardware ligado.

Funciona inclusive no celular. O layout colapsa pra coluna única.

## Modo 2 — Rodar a coisa de verdade

### 1. Ollama com os modelos

```bash
# Na máquina com a RTX 4070 Ti
ollama serve                                          # se ainda não tá rodando
ollama pull qwen2.5:14b      # raciocínio (Marina, Camila, gerente)
ollama pull llama3.1:8b      # executivos (Rafael, Helena)
ollama pull mistral:7b       # criativo (Bruno)
```

Se o Ollama está em outra máquina da rede, exporta antes de subir o servidor:

```bash
export OLLAMA_HOST=http://192.168.0.42:11434
```

### 2. Backend Python

```bash
python -m venv .venv && source .venv/bin/activate
pip install crewai 'crewai-tools[all]' fastapi 'uvicorn[standard]' \
            sse-starlette langchain-ollama

uvicorn souza_agency:app --host 0.0.0.0 --port 8765 --reload
```

Testa:

```bash
curl http://localhost:8765/health
```

### 3. Disparar um run

```bash
curl -X POST http://localhost:8765/run \
  -H "Content-Type: application/json" \
  -d '{"brief":"Estratégia de canal no YouTube sobre IA local para CTOs"}'

# resposta: {"run_id":"a1b2c3d4e5f6"}
```

### 4. Consumir o stream (CLI rápido)

```bash
curl -N http://localhost:8765/stream/a1b2c3d4e5f6
```

Você vai ver SSE assim:

```
event: delegate
data: {"agent":"marina","msg":"Brief recebido...","thought":"..."}

event: think
data: {"agent":"rafael","msg":"Buscando trends..."}

event: deliver
data: {"agent":"rafael","output":{"title":"Mapa de demanda",...}}
```

## Conectar o dashboard ao backend real

O HTML standalone roda só a simulação. Pra conectar no backend de verdade,
substitua o `run()` no `<script>` do HTML por algo como:

```javascript
async function run() {
  state.running = true;
  clearStream();
  startClock();

  const res = await fetch('http://localhost:8765/run', {
    method: 'POST',
    headers: {'Content-Type':'application/json'},
    body: JSON.stringify({ brief: $('#brief-input').value }),
  });
  const { run_id } = await res.json();

  const es = new EventSource(`http://localhost:8765/stream/${run_id}`);
  es.onmessage = (e) => {
    const ev = JSON.parse(e.data);
    if (ev.kind === 'delegate' || ev.kind === 'think' || ev.kind === 'review') {
      setAgentState(ev.agent, 'working');
    }
    appendEvent({
      agent: ev.agent, tag: ev.kind,
      head: ev.head, msg: ev.msg, thought: ev.thought,
    }, state.events);
    if (ev.output) appendOutput(ev.output);
    if (ev.final) { es.close(); finish(); }
  };
}
```

## Por que essa arquitetura

- **`Process.hierarchical` no CrewAI**: a Marina é gerente — ela decide quem
  faz o quê e quando, em vez de pipeline fixo. Isso espelha como uma agência
  real opera.
- **Modelos diferentes por papel**: você não precisa do Qwen 14B pra revisar
  texto. Usar Llama 8B em papéis executivos libera VRAM e acelera o run.
  Roteamento explícito no `LLMS = {...}`.
- **SSE em vez de WebSocket**: SSE é mais simples, suficiente pra
  unidirecional (servidor → dashboard), e atravessa proxies/CDNs sem drama.
- **`step_callback` + `callback` de Task**: o CrewAI emite hooks em cada
  passo de raciocínio e no fim de cada task. Isso é o que alimenta o
  "pensamento ao vivo" no dashboard.

## Próximos passos óbvios

1. **Tools reais**: troca os stubs de `web_search` por SearxNG self-hosted
   (já que tu valoriza não depender de API externa).
2. **Memória persistente**: CrewAI suporta `memory=True` na Crew, usando
   ChromaDB local. Roda no homelab K8s sem drama.
3. **Observabilidade**: plugar Langfuse self-hosted pra rastrear cada chamada
   de LLM, custo (se um dia for híbrido), latência por agente. Vale pra
   teu portfolio de CTO.
4. **Multi-tenant**: trocar a `EventBus` em memória por Redis pub/sub, e o
   dicionário de runs por Postgres. Aí escala pra mais de um cliente.
5. **K8s deploy**: empacotar `souza_agency.py` em container, deployar no teu
   cluster com Istio (já que você instalou recentemente). Boa oportunidade
   de validar mTLS entre o gateway e o serviço.
