module Memory #(
    parameter MEMORY_FILE = "",
    parameter MEMORY_SIZE = 4096,
    parameter DATA_WIDTH = 32
)(
    input  logic        clk,

    input  logic        cyc_i,      // Indica uma transação ativa
    input  logic        stb_i,      // Indica uma solicitação ativa
    input  logic        we_i,       // 1 = Write, 0 = Read

    input  logic [31:0] addr_i,     // Endereço
    input  logic [DATA_WIDTH/8-1:0] sel_i,
    input  logic [DATA_WIDTH-1:0] data_i,
    output logic [DATA_WIDTH-1:0] data_o,

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
    for (genvar lane = 0; lane < DATA_WIDTH/32; lane++) begin : READ_LANES
        assign data_o[lane*32 +: 32] = (cyc_i && stb_i && !we_i)
            ? memory[(addr_i[BIT_INDEX:2] + lane) % (MEMORY_SIZE/4)] : 32'd0;
    end

    // Resposta assíncrona de ACK (igual ao antigo `response`)
    assign ack_o = cyc_i && stb_i;  

    // Escrita síncrona
    always_ff @(posedge clk) begin : MEMORY_SYNC_WRITE
        if (cyc_i && stb_i && we_i) begin
            for (int lane = 0; lane < DATA_WIDTH/32; lane++) begin
                for (int byte_index = 0; byte_index < 4; byte_index++) begin
                    if (sel_i[lane*4 + byte_index])
                        memory[(addr_i[BIT_INDEX:2] + lane) % (MEMORY_SIZE/4)][byte_index*8 +: 8]
                            <= data_i[lane*32 + byte_index*8 +: 8];
                end
            end
        end
    end

endmodule
