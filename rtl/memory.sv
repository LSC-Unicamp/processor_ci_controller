module Memory #(
    parameter MEMORY_FILE = "",
    parameter MEMORY_SIZE = 4096
)(
    input  logic        clk,

    input  logic        cyc_i,      // Indica uma transação ativa
    input  logic        stb_i,      // Indica uma solicitação ativa
    input  logic        we_i,       // 1 = Write, 0 = Read
    input  logic [3:0]  sel_i,

    input  logic [31:0] addr_i,     // Endereço
    input  logic [31:0] data_i,     // Dados de entrada (para escrita)
    output logic [31:0] data_o,     // Dados de saída (para leitura)

    output logic        ack_o       // Confirmação da transação (agora assíncrona)
);

    localparam BIT_INDEX = $clog2(MEMORY_SIZE) - 1'b1;
    logic [31:0] memory [(MEMORY_SIZE/4)-1:0];

    // Inicialização da memória com arquivo, se fornecido
    initial begin
        if (MEMORY_FILE != "") begin
            $readmemh(MEMORY_FILE, memory);
        end
    end

    // Leitura assíncrona
    wire address_valid = addr_i < MEMORY_SIZE;
    assign data_o = (cyc_i && stb_i && !we_i && address_valid) ? memory[addr_i[BIT_INDEX:2]] : 32'd0;

    // Resposta assíncrona de ACK (igual ao antigo `response`)
    assign ack_o = cyc_i && stb_i && address_valid;

    // Escrita síncrona
    always_ff @(posedge clk) begin : MEMORY_SYNC_WRITE
        if (cyc_i && stb_i && we_i && address_valid) begin
            for (int lane = 0; lane < 4; lane++) begin
                if (sel_i[lane])
                    memory[addr_i[BIT_INDEX:2]][8*lane +: 8] <= data_i[8*lane +: 8];
            end
        end
    end

endmodule

// One address space with independent instruction and data ports. The host
// loader uses port A while the core is stopped; both core ports see its image.
module MemoryShared #(
    parameter MEMORY_FILE = "",
    parameter MEMORY_SIZE = 524288,
    parameter ACCESSIBLE_BYTES = MEMORY_SIZE
)(
    input logic clk,
    input logic a_cyc_i, a_stb_i, a_we_i,
    input logic [3:0] a_sel_i,
    input logic [31:0] a_addr_i, a_data_i,
    output logic [31:0] a_data_o,
    output logic a_ack_o,
    input logic b_cyc_i, b_stb_i, b_we_i,
    input logic [3:0] b_sel_i,
    input logic [31:0] b_addr_i, b_data_i,
    output logic [31:0] b_data_o,
    output logic b_ack_o
);
    localparam INDEX_BITS = $clog2(MEMORY_SIZE) - 1;
    logic [31:0] memory [0:(MEMORY_SIZE/4)-1];
    wire a_valid = a_addr_i < ACCESSIBLE_BYTES;
    wire b_valid = b_addr_i < ACCESSIBLE_BYTES;
    initial if (MEMORY_FILE != "") $readmemh(MEMORY_FILE, memory);
    assign a_ack_o = a_cyc_i && a_stb_i && a_valid;
    assign b_ack_o = b_cyc_i && b_stb_i && b_valid;
    assign a_data_o = (a_ack_o && !a_we_i) ? memory[a_addr_i[INDEX_BITS:2]] : 32'b0;
    assign b_data_o = (b_ack_o && !b_we_i) ? memory[b_addr_i[INDEX_BITS:2]] : 32'b0;
    always_ff @(posedge clk) begin
        if (a_ack_o && a_we_i)
            for (int lane = 0; lane < 4; lane++)
                if (a_sel_i[lane]) memory[a_addr_i[INDEX_BITS:2]][8*lane +: 8] <= a_data_i[8*lane +: 8];
        if (b_ack_o && b_we_i)
            for (int lane = 0; lane < 4; lane++)
                if (b_sel_i[lane]) memory[b_addr_i[INDEX_BITS:2]][8*lane +: 8] <= b_data_i[8*lane +: 8];
    end
endmodule
