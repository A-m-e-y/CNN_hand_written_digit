`timescale 1ns/1ps

module matrixmul_axi_wrapper #(
    // Users to add parameters here
    parameter MAX_M = 16,
    parameter MAX_K = 16,
    parameter MAX_N = 16,
    // User parameters ends
    
    // Do not modify the parameters beyond this line
    // Parameters of Axi Slave Bus Interface S00_AXI
    parameter integer C_S00_AXI_DATA_WIDTH = 32,
    parameter integer C_S00_AXI_ADDR_WIDTH = 8
)(
    // Users to add ports here
    // User ports ends
    
    // Do not modify the ports beyond this line
    // Ports of Axi Slave Bus Interface S00_AXI
    input wire s00_axi_aclk,
    input wire s00_axi_aresetn,
    input wire [C_S00_AXI_ADDR_WIDTH-1:0] s00_axi_awaddr,
    input wire [2:0] s00_axi_awprot,
    input wire s00_axi_awvalid,
    output wire s00_axi_awready,
    input wire [C_S00_AXI_DATA_WIDTH-1:0] s00_axi_wdata,
    input wire [(C_S00_AXI_DATA_WIDTH/8)-1:0] s00_axi_wstrb,
    input wire s00_axi_wvalid,
    output wire s00_axi_wready,
    output wire [1:0] s00_axi_bresp,
    output wire s00_axi_bvalid,
    input wire s00_axi_bready,
    input wire [C_S00_AXI_ADDR_WIDTH-1:0] s00_axi_araddr,
    input wire [2:0] s00_axi_arprot,
    input wire s00_axi_arvalid,
    output wire s00_axi_arready,
    output wire [C_S00_AXI_DATA_WIDTH-1:0] s00_axi_rdata,
    output wire [1:0] s00_axi_rresp,
    output wire s00_axi_rvalid,
    input wire s00_axi_rready
);

    // Calculate address widths
    localparam ADDR_M_BITS = $clog2(MAX_M);
    localparam ADDR_K_BITS = $clog2(MAX_K);
    localparam ADDR_N_BITS = $clog2(MAX_N);
    localparam MAX_ADDR_A = MAX_M * MAX_K;
    localparam MAX_ADDR_B = MAX_K * MAX_N;
    localparam MAX_ADDR_C = MAX_M * MAX_N;
    localparam ADDR_A_BITS = $clog2(MAX_ADDR_A);
    localparam ADDR_B_BITS = $clog2(MAX_ADDR_B);
    localparam ADDR_C_BITS = $clog2(MAX_ADDR_C);
    localparam ADDR_WIDTH = $clog2((MAX_M > MAX_K ? (MAX_M > MAX_N ? MAX_M : MAX_N) : (MAX_K > MAX_N ? MAX_K : MAX_N)));

    // Internal signals
    wire engine_start;
    wire engine_done;
    wire engine_busy;
    wire [ADDR_M_BITS:0] M_val;
    wire [ADDR_K_BITS:0] K_val;
    wire [ADDR_N_BITS:0] N_val;
    
    // AXI to Memory A interface
    wire axi_mem_a_we;
    wire [ADDR_A_BITS-1:0] axi_mem_a_addr;
    wire [31:0] axi_mem_a_wdata;
    wire [31:0] axi_mem_a_rdata;
    
    // AXI to Memory B interface
    wire axi_mem_b_we;
    wire [ADDR_B_BITS-1:0] axi_mem_b_addr;
    wire [31:0] axi_mem_b_wdata;
    wire [31:0] axi_mem_b_rdata;
    
    // AXI to Memory C interface
    wire axi_mem_c_we;
    wire [ADDR_C_BITS-1:0] axi_mem_c_addr;
    wire [31:0] axi_mem_c_wdata;
    wire [31:0] axi_mem_c_rdata;
    
    // Engine to Memory A interface
    wire [ADDR_A_BITS-1:0] engine_mem_a_addr;
    wire [31:0] engine_mem_a_rdata;
    
    // Engine to Memory B interface
    wire [ADDR_B_BITS-1:0] engine_mem_b_addr;
    wire [31:0] engine_mem_b_rdata;
    
    // Engine to Memory C interface
    wire engine_mem_c_we;
    wire [ADDR_C_BITS-1:0] engine_mem_c_addr;
    wire [31:0] engine_mem_c_wdata;
    
    // Dual-port BRAM multiplexing signals
    wire [ADDR_A_BITS-1:0] mem_a_addr_port_b;
    wire [31:0] mem_a_rdata_port_b;
    
    wire [ADDR_B_BITS-1:0] mem_b_addr_port_b;
    wire [31:0] mem_b_rdata_port_b;
    
    wire mem_c_we_port_b;
    wire [ADDR_C_BITS-1:0] mem_c_addr_port_b;
    wire [31:0] mem_c_wdata_port_b;
    wire [31:0] mem_c_rdata_port_b;
    
    // Engine busy signal generation
    reg engine_running;
    always @(posedge s00_axi_aclk) begin
        if (!s00_axi_aresetn) begin
            engine_running <= 1'b0;
        end else begin
            if (engine_start) begin
                engine_running <= 1'b1;
            end else if (engine_done) begin
                engine_running <= 1'b0;
            end
        end
    end
    assign engine_busy = engine_running;
    
    // Port B assignments for engine
    assign mem_a_addr_port_b = engine_mem_a_addr;
    assign engine_mem_a_rdata = mem_a_rdata_port_b;
    
    assign mem_b_addr_port_b = engine_mem_b_addr;
    assign engine_mem_b_rdata = mem_b_rdata_port_b;
    
    assign mem_c_we_port_b = engine_mem_c_we;
    assign mem_c_addr_port_b = engine_mem_c_addr;
    assign mem_c_wdata_port_b = engine_mem_c_wdata;

    // Instantiation of AXI Bus Interface S00_AXI
    matrixmul_axi_slave #(
        .C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH),
        .MAX_M(MAX_M),
        .MAX_K(MAX_K),
        .MAX_N(MAX_N),
        .ADDR_M_BITS(ADDR_M_BITS),
        .ADDR_K_BITS(ADDR_K_BITS),
        .ADDR_N_BITS(ADDR_N_BITS),
        .MAX_ADDR_A(MAX_ADDR_A),
        .MAX_ADDR_B(MAX_ADDR_B),
        .MAX_ADDR_C(MAX_ADDR_C),
        .ADDR_A_BITS(ADDR_A_BITS),
        .ADDR_B_BITS(ADDR_B_BITS),
        .ADDR_C_BITS(ADDR_C_BITS)
    ) axi_slave_inst (
        .S_AXI_ACLK(s00_axi_aclk),
        .S_AXI_ARESETN(s00_axi_aresetn),
        .S_AXI_AWADDR(s00_axi_awaddr),
        .S_AXI_AWPROT(s00_axi_awprot),
        .S_AXI_AWVALID(s00_axi_awvalid),
        .S_AXI_AWREADY(s00_axi_awready),
        .S_AXI_WDATA(s00_axi_wdata),
        .S_AXI_WSTRB(s00_axi_wstrb),
        .S_AXI_WVALID(s00_axi_wvalid),
        .S_AXI_WREADY(s00_axi_wready),
        .S_AXI_BRESP(s00_axi_bresp),
        .S_AXI_BVALID(s00_axi_bvalid),
        .S_AXI_BREADY(s00_axi_bready),
        .S_AXI_ARADDR(s00_axi_araddr),
        .S_AXI_ARPROT(s00_axi_arprot),
        .S_AXI_ARVALID(s00_axi_arvalid),
        .S_AXI_ARREADY(s00_axi_arready),
        .S_AXI_RDATA(s00_axi_rdata),
        .S_AXI_RRESP(s00_axi_rresp),
        .S_AXI_RVALID(s00_axi_rvalid),
        .S_AXI_RREADY(s00_axi_rready),
        
        .engine_start(engine_start),
        .engine_done(engine_done),
        .engine_busy(engine_busy),
        .M_val(M_val),
        .K_val(K_val),
        .N_val(N_val),
        
        .mem_a_we(axi_mem_a_we),
        .mem_a_addr(axi_mem_a_addr),
        .mem_a_wdata(axi_mem_a_wdata),
        .mem_a_rdata(axi_mem_a_rdata),
        
        .mem_b_we(axi_mem_b_we),
        .mem_b_addr(axi_mem_b_addr),
        .mem_b_wdata(axi_mem_b_wdata),
        .mem_b_rdata(axi_mem_b_rdata),
        
        .mem_c_we(axi_mem_c_we),
        .mem_c_addr(axi_mem_c_addr),
        .mem_c_wdata(axi_mem_c_wdata),
        .mem_c_rdata(axi_mem_c_rdata)
    );

    // Dual-Port BRAM for Matrix A
    dual_port_bram #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(ADDR_A_BITS),
        .DEPTH(MAX_ADDR_A)
    ) matrix_a_bram (
        .clk(s00_axi_aclk),
        
        // Port A: AXI access
        .addr_a(axi_mem_a_addr),
        .din_a(axi_mem_a_wdata),
        .we_a(axi_mem_a_we),
        .dout_a(axi_mem_a_rdata),
        
        // Port B: Engine access (read-only)
        .addr_b(mem_a_addr_port_b),
        .din_b(32'b0),
        .we_b(1'b0),
        .dout_b(mem_a_rdata_port_b)
    );

    // Dual-Port BRAM for Matrix B
    dual_port_bram #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(ADDR_B_BITS),
        .DEPTH(MAX_ADDR_B)
    ) matrix_b_bram (
        .clk(s00_axi_aclk),
        
        // Port A: AXI access
        .addr_a(axi_mem_b_addr),
        .din_a(axi_mem_b_wdata),
        .we_a(axi_mem_b_we),
        .dout_a(axi_mem_b_rdata),
        
        // Port B: Engine access (read-only)
        .addr_b(mem_b_addr_port_b),
        .din_b(32'b0),
        .we_b(1'b0),
        .dout_b(mem_b_rdata_port_b)
    );

    // Dual-Port BRAM for Matrix C
    dual_port_bram #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(ADDR_C_BITS),
        .DEPTH(MAX_ADDR_C)
    ) matrix_c_bram (
        .clk(s00_axi_aclk),
        
        // Port A: AXI access
        .addr_a(axi_mem_c_addr),
        .din_a(axi_mem_c_wdata),
        .we_a(axi_mem_c_we),
        .dout_a(axi_mem_c_rdata),
        
        // Port B: Engine access (write-only)
        .addr_b(mem_c_addr_port_b),
        .din_b(mem_c_wdata_port_b),
        .we_b(mem_c_we_port_b),
        .dout_b(mem_c_rdata_port_b)
    );

    // Instantiation of MatrixMulEngine with BRAM interface
    MatrixMulEngine_BRAM #(
        .MAX_M(MAX_M),
        .MAX_K(MAX_K),
        .MAX_N(MAX_N),
        .ADDR_M_BITS(ADDR_M_BITS),
        .ADDR_K_BITS(ADDR_K_BITS),
        .ADDR_N_BITS(ADDR_N_BITS),
        .ADDR_A_BITS(ADDR_A_BITS),
        .ADDR_B_BITS(ADDR_B_BITS),
        .ADDR_C_BITS(ADDR_C_BITS),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) matrix_engine (
        .clk(s00_axi_aclk),
        .rst_n(s00_axi_aresetn),
        .start(engine_start),
        .done(engine_done),
        
        .M_val(M_val),
        .K_val(K_val),
        .N_val(N_val),
        
        .matrix_A_addr(engine_mem_a_addr),
        .matrix_A_rdata(engine_mem_a_rdata),
        
        .matrix_B_addr(engine_mem_b_addr),
        .matrix_B_rdata(engine_mem_b_rdata),
        
        .matrix_C_we(engine_mem_c_we),
        .matrix_C_addr(engine_mem_c_addr),
        .matrix_C_wdata(engine_mem_c_wdata)
    );

endmodule

