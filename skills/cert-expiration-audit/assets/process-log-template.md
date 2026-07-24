# Proceso de validación — Auditoría de certificados

<!--
Un bloque por dominio, en el orden del listado original. Incluye los comandos
ejecutados y su salida relevante (no todo el output crudo si es muy largo),
terminando en una conclusión de una línea. Alguien que no ejecutó nada debería
poder llegar a la misma clasificación leyendo solo esta sección.
-->

## Dominio N — <common-name>

**DNS**

```
$ dig +short @<resolver-interno> <common-name>
<resultado>

$ dig +short @8.8.8.8 <common-name>
<resultado>
```

**ACM**

```
$ aws acm list-certificates --region <region> --query "..."
<resultado>
```

**Verificación de destino** (si aplica: ELB/ALB/CloudFront)

```
$ aws elbv2 describe-load-balancers --region <region> --names <nombre>
<resultado>
```

**Conclusión: <Renovar | No renovar | Reportar> — <motivo en una línea>**

---
