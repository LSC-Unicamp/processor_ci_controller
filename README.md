# ProcessorCI Controller

ProcessorCI Controller is the FPGA-side hardware infrastructure that wraps a
processor core, controls its clock/reset/memory access, and interprets commands
from the host communication protocol.

This repository owns the controller RTL, board projects, testbenches, examples,
and MkDocs documentation for hardware integration.

## Repository Layout

```text
rtl/          Controller, interpreter, memory, reset, timer, and bus adapters
modules/      Communication modules and optional integrations
fpga/         Board-specific projects, constraints, and scripts
testbenchs/   HDL testbenches
examples/     Example processor integrations
docs/         MkDocs documentation
mkdocs.yml    Documentation site configuration
Makefile      Hardware test/build helpers
```

## Controller Modules

The main controller blocks are:

- Interpreter: receives protocol commands and dispatches controller actions.
- Communication module: connects host communication to the controller.
- Clock controller: provides controlled pulses or divided clocks.
- Memory controller: arbitrates memory access between controller and processor.
- Bus adapters: bridge supported processor bus protocols to the internal memory
  interface.

See the documentation site for diagrams and board-specific notes.

## Supported Boards

Current board/project directories include:

- Digilent Nexys 4 DDR.
- Tang Nano 20K.
- Colorlight i9.
- Digilent Arty A7 100T.
- Xilinx VC709.
- ZedBoard.
- OpenSDRLab Kintex-7.
- Cyclone 10 GX.

## Quick Start

Clone and initialize optional submodules when needed:

```bash
git clone https://github.com/LSC-Unicamp/processor_ci_controller.git
cd processor_ci_controller
git submodule update --init --recursive
```

Run available local hardware checks through the Makefile:

```bash
make fifo
make clk_divider
```

Board builds use the corresponding directory under `fpga/` and require the
matching vendor or open-source FPGA toolchain.

## Documentation

Serve the MkDocs site locally:

```bash
pip install -r requirements.txt
mkdocs serve
```

Documentation pages under `docs/` are the canonical source for protocol,
integration, board, and usage guidance.

## Development

Keep RTL, testbench, board, and documentation changes together when modifying
controller behavior. If a protocol command changes, update the communication
repository and docs in the same feature branch or release plan.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Include the target board/toolchain and
simulation output when reporting hardware issues.

## License

See [LICENSE](LICENSE) and documentation license files.
