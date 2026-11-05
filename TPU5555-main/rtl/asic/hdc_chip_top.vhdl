library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Full-chip top for IHP SG13CMOS5L: sg13cmos5l IO pad ring around
-- hdc_word40_top. Pads are black boxes (extended identifiers keep the
-- cell/pin case through GHDL). Pad power pins (vdd/vss/iovdd/iovss) are
-- not modelled here; LibreLane connects them via PDN_MACRO_CONNECTIONS.
-- Instance names of all pads end in "_pad" (relied on by config.yaml).
--
-- The MDLL (i_mdll, a hard macro: ip/mdll/) is a separate test structure
-- with its own pads, sharing only the core supply: its reference clock and
-- reset come from pads, its code[7:0] and locked go to pads, and its output
-- clock leaves through a /4 counter, so at lock the pad toggles at the
-- reference frequency (the MDLL multiplies by 4).
entity hdc_chip_top is
    generic (
        G_CLK_FREQ_HZ : integer := 50_000_000  -- informational; CLOCK_PERIOD in config.yaml
    );
    port (
        pad_clk  : inout std_logic;
        pad_rstn : inout std_logic;
        pad_led  : inout std_logic;
        -- SPI slave (sclk/cs_n also clock flops in the SPI front end)
        pad_sclk : inout std_logic;
        pad_mosi : inout std_logic;
        pad_cs_n : inout std_logic;
        pad_miso : inout std_logic;
        -- Unused inputs: their IOPadIn cells only add gate area on the IO
        -- ring's vdd net (KLayout Ant.e on the ring rails; see config.yaml)
        pad_spare : inout std_logic_vector(4 downto 0);
        -- MDLL
        pad_mdll_clk_ref : inout std_logic;
        pad_mdll_resetb  : inout std_logic;
        pad_mdll_clk     : inout std_logic;  -- clk_out / 4
        pad_mdll_clk_raw : inout std_logic;  -- clk_out itself
        pad_mdll_locked  : inout std_logic;
        pad_mdll_code    : inout std_logic_vector(7 downto 0)
    );
end hdc_chip_top;

architecture rtl of hdc_chip_top is

    component \sg13cmos5l_IOPadIn\ is
        port (
            \pad\ : inout std_logic;
            \p2c\ : out   std_logic
        );
    end component;

    component \sg13cmos5l_IOPadOut30mA\ is
        port (
            \pad\ : inout std_logic;
            \c2p\ : in    std_logic
        );
    end component;

    -- MDLL outputs: 4 mA for code/locked (they change at most at the dither
    -- rate; weak drivers keep supply bounce away from the ring), 16 mA for
    -- the /4 clock, 30 mA for clk_out itself (4x the reference at lock; the
    -- pad shows whether the IO cell passes it, the /4 pad is the fallback).
    component \sg13cmos5l_IOPadOut4mA\ is
        port (
            \pad\ : inout std_logic;
            \c2p\ : in    std_logic
        );
    end component;

    component \sg13cmos5l_IOPadOut16mA\ is
        port (
            \pad\ : inout std_logic;
            \c2p\ : in    std_logic
        );
    end component;

    -- Hard macro, black box here (Liberty and LEF from ip/mdll/).
    component mdll is
        port (
            clk_ref : in  std_logic;
            resetb  : in  std_logic;
            clk_out : out std_logic;
            locked  : out std_logic;
            code    : out std_logic_vector(7 downto 0)
        );
    end component;

    component \sg13cmos5l_IOPadVdd\ is end component;
    component \sg13cmos5l_IOPadVss\ is end component;
    component \sg13cmos5l_IOPadIOVdd\ is end component;
    component \sg13cmos5l_IOPadIOVss\ is end component;

    signal clk, rstn, led, sclk, mosi, cs_n, miso : std_logic;

    signal mdll_clk_ref, mdll_resetb, mdll_clk_out, mdll_locked : std_logic;
    signal mdll_code : std_logic_vector(7 downto 0);
    signal mdll_div  : unsigned(1 downto 0);

begin

    -- Core supply. pdngen only straps the core ring to the pad ring on the
    -- east/west sides, so pairs 2/3 sit there; pairs 0/1 (north/south) only
    -- feed the IO ring rails.
    vdd0_pad:  \sg13cmos5l_IOPadVdd\;
    vdd1_pad:  \sg13cmos5l_IOPadVdd\;
    vdd2_pad:  \sg13cmos5l_IOPadVdd\;
    vdd3_pad:  \sg13cmos5l_IOPadVdd\;
    vss0_pad:  \sg13cmos5l_IOPadVss\;
    vss1_pad:  \sg13cmos5l_IOPadVss\;
    vss2_pad:  \sg13cmos5l_IOPadVss\;
    vss3_pad:  \sg13cmos5l_IOPadVss\;
    iovdd_pad: \sg13cmos5l_IOPadIOVdd\;
    iovss_pad: \sg13cmos5l_IOPadIOVss\;

    clk_pad:  \sg13cmos5l_IOPadIn\     port map (\pad\ => pad_clk,  \p2c\ => clk);
    rstn_pad: \sg13cmos5l_IOPadIn\     port map (\pad\ => pad_rstn, \p2c\ => rstn);
    sclk_pad: \sg13cmos5l_IOPadIn\     port map (\pad\ => pad_sclk, \p2c\ => sclk);
    mosi_pad: \sg13cmos5l_IOPadIn\     port map (\pad\ => pad_mosi, \p2c\ => mosi);
    cs_n_pad: \sg13cmos5l_IOPadIn\     port map (\pad\ => pad_cs_n, \p2c\ => cs_n);
    miso_pad: \sg13cmos5l_IOPadOut30mA\ port map (\pad\ => pad_miso, \c2p\ => miso);
    led_pad:  \sg13cmos5l_IOPadOut30mA\ port map (\pad\ => pad_led,  \c2p\ => led);

    -- Spare inputs (p2c left open; kept by pad_keep.v)
    spare0_pad: \sg13cmos5l_IOPadIn\ port map (\pad\ => pad_spare(0), \p2c\ => open);
    spare1_pad: \sg13cmos5l_IOPadIn\ port map (\pad\ => pad_spare(1), \p2c\ => open);
    spare2_pad: \sg13cmos5l_IOPadIn\ port map (\pad\ => pad_spare(2), \p2c\ => open);
    spare3_pad: \sg13cmos5l_IOPadIn\ port map (\pad\ => pad_spare(3), \p2c\ => open);
    spare4_pad: \sg13cmos5l_IOPadIn\ port map (\pad\ => pad_spare(4), \p2c\ => open);

    -- MDLL
    mdll_clk_ref_pad: \sg13cmos5l_IOPadIn\ port map (\pad\ => pad_mdll_clk_ref, \p2c\ => mdll_clk_ref);
    mdll_resetb_pad:  \sg13cmos5l_IOPadIn\ port map (\pad\ => pad_mdll_resetb,  \p2c\ => mdll_resetb);

    i_mdll: mdll
        port map (
            clk_ref => mdll_clk_ref,
            resetb  => mdll_resetb,
            clk_out => mdll_clk_out,
            locked  => mdll_locked,
            code    => mdll_code
        );

    -- clk_out / 4. Reset with the MDLL, so the pad starts low.
    process (mdll_clk_out, mdll_resetb)
    begin
        if mdll_resetb = '0' then
            mdll_div <= (others => '0');
        elsif rising_edge(mdll_clk_out) then
            mdll_div <= mdll_div + 1;
        end if;
    end process;

    mdll_clk_pad:     \sg13cmos5l_IOPadOut16mA\ port map (\pad\ => pad_mdll_clk,     \c2p\ => mdll_div(1));
    mdll_clk_raw_pad: \sg13cmos5l_IOPadOut30mA\ port map (\pad\ => pad_mdll_clk_raw, \c2p\ => mdll_clk_out);
    mdll_locked_pad: \sg13cmos5l_IOPadOut4mA\  port map (\pad\ => pad_mdll_locked, \c2p\ => mdll_locked);
    mdll_code0_pad:  \sg13cmos5l_IOPadOut4mA\  port map (\pad\ => pad_mdll_code(0), \c2p\ => mdll_code(0));
    mdll_code1_pad:  \sg13cmos5l_IOPadOut4mA\  port map (\pad\ => pad_mdll_code(1), \c2p\ => mdll_code(1));
    mdll_code2_pad:  \sg13cmos5l_IOPadOut4mA\  port map (\pad\ => pad_mdll_code(2), \c2p\ => mdll_code(2));
    mdll_code3_pad:  \sg13cmos5l_IOPadOut4mA\  port map (\pad\ => pad_mdll_code(3), \c2p\ => mdll_code(3));
    mdll_code4_pad:  \sg13cmos5l_IOPadOut4mA\  port map (\pad\ => pad_mdll_code(4), \c2p\ => mdll_code(4));
    mdll_code5_pad:  \sg13cmos5l_IOPadOut4mA\  port map (\pad\ => pad_mdll_code(5), \c2p\ => mdll_code(5));
    mdll_code6_pad:  \sg13cmos5l_IOPadOut4mA\  port map (\pad\ => pad_mdll_code(6), \c2p\ => mdll_code(6));
    mdll_code7_pad:  \sg13cmos5l_IOPadOut4mA\  port map (\pad\ => pad_mdll_code(7), \c2p\ => mdll_code(7));

    i_core: entity work.hdc_word40_top
        generic map (
            G_D           => 1000,
            G_CLK_FREQ_HZ => G_CLK_FREQ_HZ,
            G_USE_PLL     => false  -- GateMate CC_PLL, FPGA only
        )
        port map (
            clk_i  => clk,
            rstn_i => rstn,
            led_o  => led,
            sclk_i => sclk,
            mosi_i => mosi,
            miso_o => miso,
            cs_n_i => cs_n
        );

end rtl;
