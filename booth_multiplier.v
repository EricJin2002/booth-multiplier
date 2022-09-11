`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2022/09/09 21:48:58
// Design Name: 
// Module Name: booth_multiplier
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

//booth乘法器顶层模块
module booth_multiplier(
    input  [31:0] x, //被乘数
    input  [31:0] y, //乘数
    output [63:0] z  //乘积
);

//生成部分积（partial product generator, ppg）
wire [63:0] ppg_p [15:0];
wire [15:0] ppg_c;

genvar i;
generate
    for (i=0; i<16; i=i+1) begin : ppg_loop
        partial_product_generator u_ppg(
            .x({{(32-2*i){x[31]}}, x, {(2*i){1'b0}}}),
            .y({y[2*i+1], y[2*i], i==0?1'b0:y[2*i-1]}),
            .p(ppg_p[i]),
            .c(ppg_c[i])
        );
    end
endgenerate

//华莱士树（wallace tree, wt）
wire [13:0] wt_cio [64:0];
wire [63:0] wt_c;
wire [63:0] wt_s;

assign wt_cio[0] = ppg_c[13:0];

genvar j;
generate
    for (j=0; j<64; j=j+1) begin : wt_loop
        wallace_tree u_wt(
            .n      ({
                        ppg_p[15][j], ppg_p[14][j], ppg_p[13][j], ppg_p[12][j], 
                        ppg_p[11][j], ppg_p[10][j], ppg_p[ 9][j], ppg_p[ 8][j], 
                        ppg_p[ 7][j], ppg_p[ 6][j], ppg_p[ 5][j], ppg_p[ 4][j], 
                        ppg_p[ 3][j], ppg_p[ 2][j], ppg_p[ 1][j], ppg_p[ 0][j]
                    }),
            .cin    (wt_cio[j]),
            .cout   (wt_cio[j+1]),
            .c      (wt_c[j]),
            .s      (wt_s[j])
        );
        
    end
endgenerate

//64位加法器
assign z = {wt_c[62:0], ppg_c[14]} + wt_s[63:0] + ppg_c[15];

endmodule


//部分积生成模块
module partial_product_generator #(
    parameter XWIDTH = 64
)(
    input  [XWIDTH-1:0] x, //被乘数
    input  [       2:0] y, //y_{i+1}, y_{i}, y_{i-1}
    output [XWIDTH-1:0] p, //部分积
    output              c  //进位
);

wire sn;
wire sp;
wire sn2;
wire sp2;

assign sn  = ~(~( y[2]& y[1]&~y[0]) & ~( y[2]&~y[1]& y[0]));
assign sp  = ~(~(~y[2]& y[1]&~y[0]) & ~(~y[2]&~y[1]& y[0]));
assign sn2 = ~(~( y[2]&~y[1]&~y[0]));
assign sp2 = ~(~(~y[2]& y[1]& y[0]));

assign p[0] =  ~(~(sn&~x[0]) & ~(sp&x[0]) & ~sn2);
genvar i;
generate
    for (i=1; i<XWIDTH; i=i+1) begin : result_selector_loop
        assign p[i] = ~(~(sn&~x[i]) & ~(sn2&~x[i-1]) & ~(sp&x[i]) & ~(sp2&x[i-1]));
    end
endgenerate

assign c = sn | sn2;

endmodule


//一比特全加器模块
module one_bit_adder(
    input  a,   //加数
    input  b,   //被加数
    input  c,   //进位输入
    output s,   //和
    output cout //进位输出
);

assign s = ~(~(a&~b&~c) & ~(~a&b&~c) & ~(~a&~b&c) & ~(a&b&c));
assign cout = a&b | a&c | b&c;

endmodule


//华莱士树模块
module wallace_tree(
    input  [15:0] n,    //加数
    input  [13:0] cin,  //进位传递输入
    output [13:0] cout, //进位传递输出
    output        c,    //进位输出
    output        s     //和
);

wire [14:0] adder_a;
wire [14:0] adder_b;
wire [14:0] adder_c;
wire [14:0] adder_s;
wire [14:0] adder_cout;
genvar i;
generate
    for (i=0; i<15; i=i+1) begin : adder_loop
        one_bit_adder u_adder(
            .a(adder_a[i]),
            .b(adder_b[i]),
            .c(adder_c[i]),
            .s(adder_s[i]),
            .cout(adder_cout[i])
        );
    end
endgenerate

// level 1
wire [10:0] l1;
assign {adder_a[4:0], adder_b[4:0], adder_c[4:0]} = n[14:0];
assign cout[4:0] = adder_cout[4:0];
assign l1 = {adder_s[4:0], n[15], cin[4:0]};

// level 2
wire [7:0] l2;
assign {adder_a[8:5], adder_b[8:5], adder_c[8:5]} = {l1[10:0], 1'b0};
assign cout[8:5] = adder_cout[8:5];
assign l2 = {adder_s[8:5], cin[8:5]};

// level 3
wire [5:0] l3;
assign {adder_a[10:9], adder_b[10:9], adder_c[10:9]} = l2[5:0];
assign cout[10:9] = adder_cout[10:9];
assign l3 = {adder_s[10:9], l2[7:6], cin[10:9]};

// level 4
wire [3:0] l4;
assign {adder_a[12:11], adder_b[12:11], adder_c[12:11]} = l3[5:0];
assign cout[12:11] = adder_cout[12:11];
assign l4 = {adder_s[12:11], cin[12:11]};

// level 5
wire [2:0] l5;
assign {adder_a[13], adder_b[13], adder_c[13]} = l4[2:0];
assign cout[13] = adder_cout[13];
assign l5 = {adder_s[13], l4[3], cin[13]};

// level 6
assign {adder_a[14], adder_b[14], adder_c[14]} = l5[2:0];
assign c = adder_cout[14];
assign s = adder_s[14];

endmodule