private with SAM.DMAC;
private with SAM.Clock_Generator;
private with SAM.Clock_Setup_120Mhz;

package PyGamer is
   pragma Elaborate_Body;
private

   use SAM.Clock_Generator;

   Clk_CPU    : constant Generator_Id := SAM.Clock_Setup_120Mhz.Clk_CPU;
   Clk_120Mhz : constant Generator_Id := SAM.Clock_Setup_120Mhz.Clk_120Mhz;
   Clk_48Mhz  : constant Generator_Id := SAM.Clock_Setup_120Mhz.Clk_48Mhz;
   Clk_32Khz  : constant Generator_Id := SAM.Clock_Setup_120Mhz.Clk_32Khz;
   Clk_2Mhz   : constant Generator_Id := SAM.Clock_Setup_120Mhz.Clk_2Mhz;

   DMA_Descs : aliased SAM.DMAC.Descriptor_Section;
   DMA_WB : aliased SAM.DMAC.Descriptor_Section;

   DMA_DAC_0      : constant SAM.DMAC.Channel_Id := 0;
   DMA_DAC_1      : constant SAM.DMAC.Channel_Id := 1;
   DMA_Screen_SPI : constant SAM.DMAC.Channel_Id := 2;
end PyGamer;
