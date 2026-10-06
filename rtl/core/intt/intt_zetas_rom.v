// ============================================================================
// File: intt_zetas_rom.v
// Module: intt_zetas_rom
// Project: ML-KEM-512 (Kyber-512) Hardware Accelerator
//
// INTT zeta ROM. Pure combinational case statement for Genus/ASIC synthesis.
//
// intt_zetas[k] = (3329 - ntt_zetas[k]) mod 3329,  k = 1..127
// Address 0 is unused by the scheduler and holds 1.
// Verified: INTT(NTT(x)) * 128^-1 == x for all 256 coefficients.
// ============================================================================

`timescale 1ns/1ps

module intt_zetas_rom (
    input  wire [6:0]  addr,
    output reg  [12:0] zeta
);

    always @(*) begin
        case (addr)
            7'd0:   zeta = 13'd1;
            7'd1:   zeta = 13'd1600;
            7'd2:   zeta = 13'd749;
            7'd3:   zeta = 13'd40;
            7'd4:   zeta = 13'd687;
            7'd5:   zeta = 13'd2699;
            7'd6:   zeta = 13'd1432;
            7'd7:   zeta = 13'd2481;
            7'd8:   zeta = 13'd2267;
            7'd9:   zeta = 13'd1410;
            7'd10:  zeta = 13'd3136;
            7'd11:  zeta = 13'd2532;
            7'd12:  zeta = 13'd543;
            7'd13:  zeta = 13'd69;
            7'd14:  zeta = 13'd2760;
            7'd15:  zeta = 13'd1583;
            7'd16:  zeta = 13'd3033;
            7'd17:  zeta = 13'd882;
            7'd18:  zeta = 13'd1990;
            7'd19:  zeta = 13'd1853;
            7'd20:  zeta = 13'd283;
            7'd21:  zeta = 13'd3273;
            7'd22:  zeta = 13'd1089;
            7'd23:  zeta = 13'd1996;
            7'd24:  zeta = 13'd1903;
            7'd25:  zeta = 13'd1235;
            7'd26:  zeta = 13'd2794;
            7'd27:  zeta = 13'd447;
            7'd28:  zeta = 13'd936;
            7'd29:  zeta = 13'd450;
            7'd30:  zeta = 13'd1355;
            7'd31:  zeta = 13'd2508;
            7'd32:  zeta = 13'd3040;
            7'd33:  zeta = 13'd2998;
            7'd34:  zeta = 13'd76;
            7'd35:  zeta = 13'd1573;
            7'd36:  zeta = 13'd2132;
            7'd37:  zeta = 13'd1025;
            7'd38:  zeta = 13'd1052;
            7'd39:  zeta = 13'd1274;
            7'd40:  zeta = 13'd2679;
            7'd41:  zeta = 13'd1352;
            7'd42:  zeta = 13'd816;
            7'd43:  zeta = 13'd2697;
            7'd44:  zeta = 13'd464;
            7'd45:  zeta = 13'd3296;
            7'd46:  zeta = 13'd2009;
            7'd47:  zeta = 13'd1414;
            7'd48:  zeta = 13'd1010;
            7'd49:  zeta = 13'd1894;
            7'd50:  zeta = 13'd2522;
            7'd51:  zeta = 13'd2877;
            7'd52:  zeta = 13'd1891;
            7'd53:  zeta = 13'd461;
            7'd54:  zeta = 13'd1795;
            7'd55:  zeta = 13'd927;
            7'd56:  zeta = 13'd682;
            7'd57:  zeta = 13'd712;
            7'd58:  zeta = 13'd1848;
            7'd59:  zeta = 13'd2681;
            7'd60:  zeta = 13'd855;
            7'd61:  zeta = 13'd219;
            7'd62:  zeta = 13'd2102;
            7'd63:  zeta = 13'd2419;
            7'd64:  zeta = 13'd3312;
            7'd65:  zeta = 13'd568;
            7'd66:  zeta = 13'd2746;
            7'd67:  zeta = 13'd680;
            7'd68:  zeta = 13'd1692;
            7'd69:  zeta = 13'd2606;
            7'd70:  zeta = 13'd1041;
            7'd71:  zeta = 13'd2229;
            7'd72:  zeta = 13'd1920;
            7'd73:  zeta = 13'd667;
            7'd74:  zeta = 13'd48;
            7'd75:  zeta = 13'd3096;
            7'd76:  zeta = 13'd2573;
            7'd77:  zeta = 13'd1173;
            7'd78:  zeta = 13'd314;
            7'd79:  zeta = 13'd279;
            7'd80:  zeta = 13'd1626;
            7'd81:  zeta = 13'd1678;
            7'd82:  zeta = 13'd540;
            7'd83:  zeta = 13'd1540;
            7'd84:  zeta = 13'd1482;
            7'd85:  zeta = 13'd2377;
            7'd86:  zeta = 13'd1868;
            7'd87:  zeta = 13'd642;
            7'd88:  zeta = 13'd2390;
            7'd89:  zeta = 13'd1021;
            7'd90:  zeta = 13'd892;
            7'd91:  zeta = 13'd941;
            7'd92:  zeta = 13'd2596;
            7'd93:  zeta = 13'd992;
            7'd94:  zeta = 13'd3061;
            7'd95:  zeta = 13'd2688;
            7'd96:  zeta = 13'd1745;
            7'd97:  zeta = 13'd1031;
            7'd98:  zeta = 13'd1292;
            7'd99:  zeta = 13'd109;
            7'd100: zeta = 13'd2954;
            7'd101: zeta = 13'd780;
            7'd102: zeta = 13'd1239;
            7'd103: zeta = 13'd1684;
            7'd104: zeta = 13'd2266;
            7'd105: zeta = 13'd3010;
            7'd106: zeta = 13'd556;
            7'd107: zeta = 13'd2572;
            7'd108: zeta = 13'd1230;
            7'd109: zeta = 13'd2768;
            7'd110: zeta = 13'd863;
            7'd111: zeta = 13'd735;
            7'd112: zeta = 13'd525;
            7'd113: zeta = 13'd2237;
            7'd114: zeta = 13'd2926;
            7'd115: zeta = 13'd2303;
            7'd116: zeta = 13'd2186;
            7'd117: zeta = 13'd1179;
            7'd118: zeta = 13'd554;
            7'd119: zeta = 13'd2443;
            7'd120: zeta = 13'd1607;
            7'd121: zeta = 13'd2117;
            7'd122: zeta = 13'd1455;
            7'd123: zeta = 13'd2300;
            7'd124: zeta = 13'd1219;
            7'd125: zeta = 13'd394;
            7'd126: zeta = 13'd2444;
            7'd127: zeta = 13'd1175;
            default: zeta = 13'd0;
        endcase
    end

endmodule
