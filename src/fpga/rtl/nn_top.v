`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07.04.2019 20:57:54
// Design Name: 
// Module Name: top_layer
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "include.v"

module nn_top #(
    parameter integer C_S_AXI_DATA_WIDTH    = 32,
    parameter integer C_S_AXI_ADDR_WIDTH    = 5
)
(
    //Clock and Reset
    input                                   s_axi_aclk,
    input                                   s_axi_aresetn,
    //AXI Stream interface
    input [`dataWidth-1:0]                  axis_in_data,
    input                                   axis_in_data_valid,
    output                                  axis_in_data_ready,
    //AXI Lite Interface
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0]   s_axi_awaddr,
    input wire [2 : 0]                      s_axi_awprot,
    input wire                              s_axi_awvalid,
    output wire                             s_axi_awready,
    input wire [C_S_AXI_DATA_WIDTH-1 : 0]   s_axi_wdata,
    input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] s_axi_wstrb,
    input wire                              s_axi_wvalid,
    output wire                             s_axi_wready,
    output wire [1 : 0]                     s_axi_bresp,
    output wire                             s_axi_bvalid,
    input wire                              s_axi_bready,
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0]   s_axi_araddr,
    input wire [2 : 0]                      s_axi_arprot,
    input wire                              s_axi_arvalid,
    output wire                             s_axi_arready,
    output wire [C_S_AXI_DATA_WIDTH-1 : 0]  s_axi_rdata,
    output wire [1 : 0]                     s_axi_rresp,
    output wire                             s_axi_rvalid,
    input wire                              s_axi_rready,
    //Interrupt interface
    output wire                             intr
);


wire [31:0]  config_layer_num;
wire [31:0]  config_neuron_num;
wire [`numNeuronLayer1-1:0] o1_valid;
wire [`numNeuronLayer1*`dataWidth-1:0] x1_out;
wire [`numNeuronLayer2-1:0] o2_valid;
wire [`numNeuronLayer2*`dataWidth-1:0] x2_out;
wire [31:0] weightValue;
wire [31:0] biasValue;
wire [31:0] out;
wire out_valid;
wire weightValid;
wire biasValid;

assign intr = out_valid;
assign axis_in_data_ready = 1'b1;


axi_lite_wrapper # ( 
    .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
    .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH)
) alw (
    .S_AXI_ACLK(s_axi_aclk),
    .S_AXI_ARESETN(s_axi_aresetn),
    .S_AXI_AWADDR(s_axi_awaddr),
    .S_AXI_AWPROT(s_axi_awprot),
    .S_AXI_AWVALID(s_axi_awvalid),
    .S_AXI_AWREADY(s_axi_awready),
    .S_AXI_WDATA(s_axi_wdata),
    .S_AXI_WSTRB(s_axi_wstrb),
    .S_AXI_WVALID(s_axi_wvalid),
    .S_AXI_WREADY(s_axi_wready),
    .S_AXI_BRESP(s_axi_bresp),
    .S_AXI_BVALID(s_axi_bvalid),
    .S_AXI_BREADY(s_axi_bready),
    .S_AXI_ARADDR(s_axi_araddr),
    .S_AXI_ARPROT(s_axi_arprot),
    .S_AXI_ARVALID(s_axi_arvalid),
    .S_AXI_ARREADY(s_axi_arready),
    .S_AXI_RDATA(s_axi_rdata),
    .S_AXI_RRESP(s_axi_rresp),
    .S_AXI_RVALID(s_axi_rvalid),
    .S_AXI_RREADY(s_axi_rready),
    .layerNumber(config_layer_num),
    .neuronNumber(config_neuron_num),
    .weightValue(weightValue),
    .weightValid(weightValid),
    .biasValid(biasValid),
    .biasValue(biasValue),
    .nnOut_valid(out_valid),
    .nnOut(out)
);

Layer #(.NN(`numNeuronLayer1),.numWeight(`numNueuronLayer0),.layerNum(1)) l1 (
    .clk(s_axi_aclk),
    .rst(!s_axi_aresetn),
    .weightValid(weightValid),
    .biasValid(biasValid),
    .weightValue(weightValue),
    .biasValue(biasValue),
    .config_layer_num(config_layer_num),
    .config_neuron_num(config_neuron_num),
    .x_valid({`numNeuronLayer1{axis_in_data_valid}}),
    .x_in({`numNeuronLayer1{axis_in_data}}),
    .o_valid(o1_valid),
    .x_out(x1_out) 
);

reg [`numNeuronLayer1*`dataWidth-1:0] holdData;
reg [`dataWidth-1:0] firstOutput;
reg firstValid;


localparam IDLE = 'd0,
           SEND = 'd1;
       
reg       state;
integer   count;

always @(posedge s_axi_aclk)
begin
    if(!s_axi_aresetn)
    begin
        state <= IDLE;
        count <= 0;
        firstValid <=0;
    end
    else
    begin
        case(state)
            IDLE: begin
                count <= 0;
                firstValid <=0;
                if (o1_valid[0] == 1'b1)
                begin
                    holdData <= x1_out;
                    state <= SEND;
                end
            end
            SEND: begin
                firstOutput <= holdData[`dataWidth-1:0];
                holdData <= holdData>>`dataWidth;
                count <= count +1;
                firstValid <= 1;
                if (count == `numNeuronLayer1)
                begin
                    state <= IDLE;
                    firstValid <= 0;
                end
            end
       endcase
    end
end




Layer #(.NN(`numNeuronLayer2),.numWeight(`numNeuronLayer1),.layerNum(2)) l2 (
    .clk(s_axi_aclk),
    .rst(!s_axi_aresetn),
    .weightValid(weightValid),
    .biasValid(biasValid),
    .weightValue(weightValue),
    .biasValue(biasValue),
    .config_layer_num(config_layer_num),
    .config_neuron_num(config_neuron_num),
    .x_valid({`numNeuronLayer2{firstValid}}),
    .x_in({`numNeuronLayer2{firstOutput}}),
    .o_valid(o2_valid),
    .x_out(x2_out) 
);



reg [`numNeuronLayer2*`dataWidth-1:0] holdDataTwo;
reg [`dataWidth-1:0] secondOutput;
reg secondValid;
reg stateTwo;
integer countTwo;

always @(posedge s_axi_aclk)
begin
    if(!s_axi_aresetn)
    begin
        stateTwo <= IDLE;
        countTwo <= 0;
        secondValid <=0;
    end
    else
    begin
        case(stateTwo)
            IDLE: begin
                countTwo <= 0;
                secondValid <=0;
                if (o2_valid[0] == 1'b1)
                begin
                    holdDataTwo <= x2_out;
                    stateTwo <= SEND;
                end
            end
            SEND: begin
                secondOutput <= holdDataTwo[`dataWidth-1:0];
                holdDataTwo <= holdDataTwo>>`dataWidth;
                countTwo <= countTwo +1;
                secondValid <= 1;
                if (countTwo == `numNeuronLayer2)
                begin
                    stateTwo <= IDLE;
                    secondValid <= 0;
                end
            end
       endcase
    end
end

wire [`numNeuronLayer3*`dataWidth-1:0] x3_out;
wire o3_valid;

Layer #(.NN(`numNeuronLayer3),.numWeight(`numNeuronLayer2),.layerNum(3)) l3 (
    .clk(s_axi_aclk),
    .rst(!s_axi_aresetn),
    .weightValid(weightValid),
    .biasValid(biasValid),
    .weightValue(weightValue),
    .biasValue(biasValue),
    .config_layer_num(config_layer_num),
    .config_neuron_num(config_neuron_num),
    .x_valid({`numNeuronLayer3{secondValid}}),
    .x_in({`numNeuronLayer3{secondOutput}}),
    .o_valid(o3_valid),
    .x_out(x3_out) 
); 

maxFinder #(.numInput(`numNeuronLayer3),.inputWidth(`dataWidth)) 
mFind(
    .i_clk(s_axi_aclk),
    .i_data(x3_out),
    .i_valid(o3_valid),
    .o_data(out),
    .o_data_valid(out_valid)
);

endmodule
