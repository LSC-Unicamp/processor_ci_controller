`timescale 1ns/1ps

module interpreter_protocol_tb;
    logic clk = 0;
    always #5 clk = ~clk;
    logic rst_n = 0;

    logic communication_read, communication_write;
    logic communication_read_response, communication_write_response;
    logic communication_rx_empty, communication_tx_empty;
    logic [31:0] communication_read_data, communication_write_data;
    logic core_clk_enable, core_reset, write_pulse;
    logic [31:0] num_of_cycles_to_pulse;
    logic finish_execution = 0, reset_bus, bus_mode;
    logic [23:0] memory_page_size, memory_page_number;
    logic [31:0] end_position;
    logic memory_read, memory_write, memory_mux_selector;
    logic [31:0] write_data, address, read_data;

    logic [31:0] rx_fifo [0:255];
    logic [31:0] replies [0:31];
    logic [31:0] primary [0:255];
    logic [31:0] secondary [0:255];
    integer head = 0, tail = 0, reply_count = 0;
    integer i;

    assign communication_rx_empty = (head == tail);
    assign communication_read_data = rx_fifo[head];
    assign communication_read_response = !communication_rx_empty;
    assign communication_write_response = 1'b1;
    assign communication_tx_empty = 1'b1;
    assign read_data = address[31] ? secondary[address[9:2]] : primary[address[9:2]];

    always @(posedge clk) begin
        if (rst_n && communication_read)
            head <= head + 1;
        if (rst_n && communication_write) begin
            replies[reply_count] <= communication_write_data;
            reply_count <= reply_count + 1;
        end
        if (rst_n && memory_write) begin
            if (address[31]) secondary[address[9:2]] <= write_data;
            else primary[address[9:2]] <= write_data;
        end
    end

    Interpreter #(.ID(32'h12345678), .RESET_CLK_CYCLES(4)) dut (
        .clk(clk), .rst_n(rst_n),
        .communication_rx_empty(communication_rx_empty),
        .communication_tx_empty(communication_tx_empty),
        .communication_read(communication_read),
        .communication_write(communication_write),
        .communication_read_response(communication_read_response),
        .communication_write_response(communication_write_response),
        .communication_read_data(communication_read_data),
        .communication_write_data(communication_write_data),
        .core_clk_enable(core_clk_enable), .core_reset(core_reset),
        .num_of_cycles_to_pulse(num_of_cycles_to_pulse), .write_pulse(write_pulse),
        .finish_execution(finish_execution), .reset_bus(reset_bus),
        .bus_mode(bus_mode), .memory_page_size(memory_page_size),
        .end_position(end_position), .memory_response(1'b1),
        .memory_read(memory_read), .memory_write(memory_write),
        .memory_mux_selector(memory_mux_selector),
        .memory_page_number(memory_page_number), .write_data(write_data),
        .address(address), .read_data(read_data)
    );

    task automatic enqueue(input logic [31:0] word);
        begin
            rx_fifo[tail] = word;
            tail = tail + 1;
        end
    endtask

    task automatic command(input logic [7:0] opcode, input logic [23:0] immediate);
        enqueue({immediate, opcode});
    endtask

    task automatic await_reply(input integer wanted);
        integer guard;
        begin
            guard = 0;
            while (reply_count < wanted) begin
                @(posedge clk);
                guard = guard + 1;
                if (guard > 3000) $fatal(1, "response timeout");
            end
            @(negedge clk);
        end
    endtask

    task automatic await_idle;
        integer guard;
        begin
            guard = 0;
            while (head != tail || dut.state != 8'h00) begin
                @(posedge clk);
                guard = guard + 1;
                if (guard > 3000) $fatal(1, "interpreter did not become idle");
            end
            repeat (2) @(negedge clk);
        end
    endtask

    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            primary[i] = 0;
            secondary[i] = 0;
        end
        repeat (4) @(negedge clk);
        rst_n = 1;

        command(8'h70, 0);
        await_reply(1);
        if (replies[0] !== 32'h12345678) $fatal(1, "module ID mismatch");
        await_idle();

        command(8'h57, 24'd4);
        enqueue(32'h11223344);
        await_idle();
        if (primary[4] !== 32'h11223344) $fatal(1, "atomic primary write failed");
        command(8'h4c, 24'd4);
        await_reply(2);
        if (replies[1] !== 32'h11223344) $fatal(1, "atomic primary read failed");
        await_idle();

        command(8'h57, 24'h800005);
        enqueue(32'h55667788);
        await_idle();
        if (secondary[5] !== 32'h55667788) $fatal(1, "second-bank write failed");
        command(8'h4c, 24'h800005);
        await_reply(3);
        if (replies[2] !== 32'h55667788) $fatal(1, "second-bank read failed");
        await_idle();

        command(8'h55, 0);
        command(8'h6c, 24'h20);
        command(8'h65, 24'd3);
        enqueue(32'h01020304);
        enqueue(32'h05060708);
        enqueue(32'h090a0b0c);
        await_idle();
        if (primary[8] !== 32'h01020304 || primary[9] !== 32'h05060708 ||
            primary[10] !== 32'h090a0b0c) $fatal(1, "burst write failed");
        command(8'h61, 0);
        await_reply(4);
        if (replies[3] !== 32'h20) $fatal(1, "burst advanced accumulator");
        await_idle();

        command(8'h44, 24'd12);
        await_idle();
        if (end_position !== 32'd48) $fatal(1, "word-index breakpoint failed");
        command(8'h6c, 24'h22);
        command(8'h64, 0);
        await_idle();
        if (end_position !== 32'h22) $fatal(1, "halfword accumulator breakpoint failed");

        command(8'h54, 24'd100);
        command(8'h75, 0);
        wait (dut.state == 8'h10);
        repeat (5) @(negedge clk);
        finish_execution = 1;
        @(negedge clk);
        finish_execution = 0;
        await_reply(6);
        if (replies[4] !== 32'h6c75636b || replies[5][0] !== 1'b1 ||
            (replies[5] >> 1) >= 100) $fatal(1, "completion packet failed");
        await_idle();

        command(8'h54, 24'd20);
        command(8'h75, 0);
        await_reply(8);
        if (replies[6] !== 32'h6c75636b || (replies[7] >> 1) !== 21 ||
            replies[7][0] !== 1'b0) $fatal(1, "timeout packet mismatch");
        $display("RTL_PROTOCOL_PASS primary, second bank, burst, breakpoints, completion, timeout");
        $finish;
    end
endmodule
