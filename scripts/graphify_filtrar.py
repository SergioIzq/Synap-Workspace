"""Copia un graph.json de graphify quitando los nodos cuyo source_file empieza por un prefijo dado.

Uso: python -I scripts/graphify_filtrar.py <origen graph.json> <destino graph.json> [prefijo ...]

Los prefijos salen de graphify.excluir en workspace.yaml. El origen nunca se modifica.
Se quitan los nodos excluidos, las aristas que los tocan y esos miembros de las hiperaristas.
"""
import json
import sys
from pathlib import Path


def filtrar(grafo: dict, excluir: tuple) -> dict:
    fuera = {
        n["id"] for n in grafo["nodes"]
        if excluir and (n.get("source_file") or "").replace("\\", "/").startswith(excluir)
    }
    grafo["nodes"] = [n for n in grafo["nodes"] if n["id"] not in fuera]
    grafo["links"] = [l for l in grafo["links"] if l["source"] not in fuera and l["target"] not in fuera]
    hiper = []
    for h in grafo.get("hyperedges", []):
        miembros = [m for m in h.get("nodes", []) if m not in fuera]
        if len(miembros) >= 2:
            hiper.append({**h, "nodes": miembros})
    grafo["hyperedges"] = hiper
    return grafo


def _comprobar() -> None:
    g = {
        "nodes": [{"id": "a", "source_file": "src/a.cs"}, {"id": "b", "source_file": "openspec\\x.md"}, {"id": "c"}],
        "links": [{"source": "a", "target": "b"}, {"source": "a", "target": "c"}],
        "hyperedges": [{"nodes": ["a", "b"]}, {"nodes": ["a", "b", "c"]}],
    }
    filtrar(g, ("openspec/",))
    assert [n["id"] for n in g["nodes"]] == ["a", "c"]
    assert g["links"] == [{"source": "a", "target": "c"}]
    assert g["hyperedges"] == [{"nodes": ["a", "c"]}]
    assert len(filtrar({"nodes": [{"id": "a", "source_file": "x"}], "links": []}, ())["nodes"]) == 1


if __name__ == "__main__":
    if sys.argv[1:] == ["--check"]:
        _comprobar()
        print("ok")
        sys.exit(0)
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    origen, destino, excluir = Path(sys.argv[1]), Path(sys.argv[2]), tuple(sys.argv[3:])
    grafo = json.loads(origen.read_text(encoding="utf-8"))
    antes = len(grafo["nodes"])
    filtrar(grafo, excluir)
    destino.parent.mkdir(parents=True, exist_ok=True)
    destino.write_text(json.dumps(grafo, ensure_ascii=False), encoding="utf-8")
    print(f"{origen} -> {destino}: {antes} -> {len(grafo['nodes'])} nodos")
