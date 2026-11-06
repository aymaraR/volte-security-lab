# srsRAN — imagen de cierre (workaround EBI)

El laboratorio usa una imagen derivada de `srsran-zmq:latest` que recompila
solo `srsue` con el workaround de EBI (Open5GS asigna EBI 5; el parser de
srsUE entrega 9).

## Construcción

```bash
cd voLTE-lab
# 1) imagen base (solo si no existe)
docker build -t srsran-zmq:latest ./srsran
# 2) imagen de cierre (recompila srsue, ~10 s con caché)
docker build -f srsran/Dockerfile.cierre -t srsran-zmq:latest ./srsran
```

La imagen resultante se usa para `srsenb`, `srsue`, `srsenb2` y `srsue2`.

## Verificación

```bash
docker run --rm srsran-zmq:latest sh -c \
  "grep -n 'CIERRE-V7' /srsran/srsue/src/stack/upper/nas.cc"
```

Debe mostrar el bloque `CIERRE-V7` y el `send_attach_complete` usando
`act_def_eps_bearer_context_req.proc_transaction_id` / `.eps_bearer_id`.
