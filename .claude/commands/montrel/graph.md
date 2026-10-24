---
name: "MONTREL: Graph"
description: "Construir el grafo graphify unificado de todos los repos de código del workspace"
allowed-tools: Bash(graphify:*), Bash(python:*), Bash(py:*), Bash(git:*), AskUserQuestion
category: Workflow
tags: [workflow, graphify, montrel]
---

Construye `graphify-out/graph.json` en este repo: un grafo unificado de los repos de `workspace.yaml`. Es un artefacto local (está en `.gitignore`). **Nunca modifica nada en los repos de código.**

## Paso 0 — comprobar requisitos

Requisitos: **Python ≥ 3.10** y **graphify ≥ 0.9.80** (paquete PyPI `graphifyy`, con doble `y`).

1. **Python:** ejecuta `python --version`. Es válido solo si imprime `Python 3.<x>` con `x ≥ 10`. En Windows, el alias de Microsoft Store (`...\WindowsApps\python.exe`) no imprime versión: cuenta como no instalado. Si `python` no vale, prueba `py --version` y, si vale, usa `py` en lugar de `python` en todo el comando.
2. **graphify:** ejecuta `graphify --version`. Si falla, prueba `python -m graphify --version` (pasa cuando el paquete está instalado pero su carpeta `Scripts` no está en el `PATH`). Usa como `<graphify>` el primero que funcione en todos los pasos siguientes. Si la versión es menor que 0.9.80, trátalo como no instalado (falta `merge-graphs`).

Si falta algo, muestra qué falta y pregunta mediante AskUserQuestion:

- **Instalar ahora.** Antes de cada instalación muestra el comando exacto y espera confirmación:
  - Python: `winget install -e --id Python.Python.3.12`. Después, el usuario debe abrir una terminal nueva y volver a ejecutar `/montrel:graph`, porque el `PATH` no se refresca en esta sesión; para aquí.
  - graphify: `python -m pip install --user --upgrade "graphifyy>=0.9.80"`. Comprueba de nuevo con el punto 2 y continúa.
- **Ver instrucciones.** Muestra esos mismos comandos para que los ejecute él, y para.
- **Continuar sin grafo.** Para aquí, sin error. El resto del flujo `/montrel:*` funciona sin grafo, buscando con grep y leyendo ficheros, y los hooks `graphify hook-guard` no hacen nada si graphify no está instalado.

Nunca instales nada sin confirmación explícita, ni con `sudo` ni como administrador.

En los pasos siguientes, `graphify` y `python` son el `<graphify>` y el intérprete resueltos aquí.

## Paso 1 — un grafo por repo

Lee `workspace.yaml`. `<excluir>` son los prefijos de `graphify.excluir`, separados por espacios (vacío si no hay). Para cada entrada de `repos` cuya `ruta` exista, resuelve su modo con el campo `grafo`. Si se omite, el modo es `propio` si existe `<ruta>/graphify-out/graph.json` y `extraer` si no.

- **`propio`**: usa el grafo del repo tal cual. **No lo regeneres ni ejecutes `graphify update` en ese repo**: lo mantiene su equipo. Si no existe, avísalo y salta el repo. Muestra su fecha de modificación y avisa si es anterior al último commit del repo (`git -C "<ruta>" log -1 --format=%ci`).

  ```text
  python -I scripts/graphify_filtrar.py "<ruta>/graphify-out/graph.json" "graphify-out/repos/<id>/graphify-out/graph.json" <excluir>
  ```

- **`extraer`**: extrae solo el código (AST local, sin LLM ni API key) en la caché de este repo y filtra. Es incremental: las siguientes ejecuciones solo reprocesan los ficheros cambiados.

  ```text
  graphify extract "<ruta>" --code-only --out "graphify-out/cache/<id>"
  python -I scripts/graphify_filtrar.py "graphify-out/cache/<id>/graphify-out/graph.json" "graphify-out/repos/<id>/graphify-out/graph.json" <excluir>
  ```

- **`ninguno`**: salta el repo.

Si un repo de `workspace.yaml` ya no está, o pasa a `ninguno`, borra su `graphify-out/repos/<id>/` para que no entre en la fusión. Si un repo falla, informa y continúa con los demás.

## Paso 2 — fusionar

Fusiona todos los `graphify-out/repos/<id>/graphify-out/graph.json` generados en el paso 1:

```text
graphify merge-graphs <grafo-1> <grafo-2> ... --out graphify-out/graph.json
```

Si solo hay uno, cópialo a `graphify-out/graph.json`. La carpeta `repos/<id>/` hace que cada nodo fusionado lleve `repo: <id>`.

## Paso 3 — resumen

Muestra una tabla `id → modo → nodos → fecha`, el total de nodos y aristas del grafo unificado, y los avisos de grafos desactualizados. Recuerda que `graphify query "<pregunta>"` usa este grafo por defecto.

## Reglas

- Nunca escribas en los repos de código: ni `graphify update`, ni `graphify extract` sin `--out`, ni `graphify hook install` en ellos.
- No uses `extract` sin `--code-only`: la extracción semántica requiere un LLM y una API key.
- Ejecuta este comando después de `/montrel:apply` o cuando `/montrel:explore` avise de que falta el grafo o está desactualizado.
