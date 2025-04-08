# HTML Sokoban

Sokoban in pure static HTML, [vibe coded](https://chatgpt.com/c/67f4394f-7d58-8012-86bd-660087b70d3f).

[Play now](game/state_00000.html)

This uses [accesskey](https://developer.mozilla.org/en-US/docs/Web/HTML/Global_attributes/accesskey) to support keyboard input. The exact key combos are system dependent. See [MDN](https://developer.mozilla.org/en-US/docs/Web/HTML/Global_attributes/accesskey) for how to trigger movement keys in your OS and browser.

For more levels, see [these small Pufiban levels](https://github.com/festoni/SokobanSolvers/blob/master/levels/), then run `perl gen.pl`.

Larger levels would be possible if the server handled the game logic, non-pre computed, with the client still pure HTML. But this would require a backend.
