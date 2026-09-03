# Menu interativo com mouse e teclado

Esta implementação foi preparada para o projeto ASIMOV em Godot 4. Ela está ativa em:

- menu principal e todas as suas telas de opções;
- menu de pausa e todas as suas telas de opções;
- tela de seleção de profissão, personagem e dificuldade.

## Arquivos adicionados

- `Scripts/UI/menu_input_router.gd`: detecta o dispositivo, gerencia o foco, o contorno e o leitor de tela.
- `Sprites/ui/InputMode/mouse.svg`: ícone do modo mouse.
- `Sprites/ui/InputMode/keyboard.svg`: ícone do modo teclado.

O nó `MenuInputRouter` também foi adicionado a estas cenas:

- `Scenes/principal.tscn`;
- `Scenes/pause_menu.tscn`;
- `Scenes/slectionpage.tscn`.

## Como usar

1. Mova o mouse ou clique para entrar no modo mouse.
2. Pressione uma tecla para entrar no modo teclado.
3. No teclado, navegue com as setas ou `W`, `A`, `S`, `D`.
4. Use `Enter` ou `Espaço` para ativar o item selecionado.
5. O item selecionado pelo teclado recebe um contorno amarelo.
6. O canto superior direito mostra somente o ícone do modo atual em uma caixa cinza.

O sistema procura automaticamente a tela de menu visível. Assim, quando o jogador abre Opções, Volume, Interface, Acessibilidade ou Controles, o foco passa para o primeiro item daquela tela.

## Leitor de tela

Com o leitor de tela ativado, cada novo foco recebido pelo teclado é anunciado. Com o leitor desativado, a mesma navegação e o mesmo contorno continuam funcionando normalmente.

## Adicionar a outro menu

Para usar o mesmo comportamento em outra cena:

1. Adicione um nó do tipo `Node` como filho direto da raiz do menu.
2. Nomeie-o `MenuInputRouter`.
3. Anexe `res://Scripts/UI/menu_input_router.gd` ao nó.

Não é necessário cadastrar os botões manualmente. Controles focáveis visíveis são encontrados automaticamente.

## Checklist de teste

- Menu principal: navegar, confirmar e voltar somente pelo teclado.
- Opções do menu principal: testar botões, caixas, seletores e sliders.
- Pausa: abrir com `Esc`, navegar, confirmar e voltar.
- Mover o mouse após usar o teclado: o ícone deve mudar para mouse e o contorno deve sumir.
- Pressionar uma tecla após usar o mouse: o ícone deve mudar para teclado e o contorno deve aparecer.
- Nas configurações, focar o X e usar qualquer seta: o foco deve voltar para o primeiro controle da tela.
- Confirmar que o X não aumenta de tamanho nem ultrapassa a borda direita da tela.
- Repetir os testes com o leitor de tela ativado e desativado.
