# Diálogos e pensamentos

Todos os textos de conversa e pensamentos ficam em `dialogues.pt_BR.json`. O autoload `DialogueCatalog` lê esse recurso; o `DialogManager` continua exibindo as conversas e controlando suas interrupções. Tarefas, tutoriais de controles e perguntas dos minigames continuam nos seus próprios sistemas.

## Formato

`actors` reúne os personagens e seus nomes. Cada chave de `lines` é um ID único de fala:

```json
"hall.intro.extinguisher": {
  "sender_id": "player",
  "recipient_id": "player",
  "thought": true,
  "text": "Preciso de um extintor."
}
```

- `sender_id`: personagem que fala ou pensa.
- `recipient_id`: destinatário. Nos pensamentos, é o mesmo personagem.
- `thought`: indica um pensamento.
- `text`: conteúdo, sem prefixo de nome.
- `show_speaker`: quando verdadeiro, o sistema acrescenta o nome do remetente antes da fala.
- `metadata`: parâmetros específicos da sequência, como `damaged`, `tom`, `tempo`, `status`, `before_stage` e `gatilho`.

`sequences` guarda listas ordenadas de IDs. Há variantes para os itens encontrados no escritório, a profissão escolhida e o momento da queda de energia. Os finais também mantêm suas sequências e parâmetros no catálogo.

## Uso no código

```gdscript
DialogManager.start_catalog_dialog("data_center.card_delivery", CARD_DIALOG_ID)
player.balao_de_pensamento.enfileirar_dialogo("hall.intro.extinguisher", "hall:extintor")
await player.balao_de_pensamento.mostrar_dialogo("programmer.confrontation.1", "programmer:confrontation:1")
```

`DialogueCatalog.text(id)` retorna uma fala; `texts(sequence_id)` retorna textos; `entries(sequence_id)` retorna falas com participantes e metadados. `DialogManager.current_line_data` informa quem envia e recebe a fala atual.

Para editar a escrita, altere `text` no JSON. Para reorganizar uma conversa, altere sua lista em `sequences`. Preserve os IDs das falas referenciadas no código e os IDs legados de pensamentos em `metadata.id`: eles mantêm a compatibilidade com os checkpoints.

Os métodos antigos de texto continuam disponíveis para retomar saves anteriores. Novos diálogos devem usar o catálogo. A opção `repetivel` do balão permite repetir avisos sem acumular cópias enquanto estiverem visíveis.

Validação: `Tests/dialogue_catalog_test.tscn` verifica participantes, sequências, scripts migrados, pensamentos repetíveis, checkpoints, variantes do escritório e interrupção/retomada de conversas.
