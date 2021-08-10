with SAM.Device; use SAM.Device;
with SAM.Port;
with SAM.SERCOM;
with SAM.SERCOM.SPI;
with SAM.Main_Clock;
with SAM.Functions;
with SAM.Clock_Generator;
with SAM.Clock_Generator.IDs;

with ST7735R; use ST7735R;

with HAL;     use HAL;
with HAL.SPI; use HAL.SPI;

with HAL.GPIO;

with PyGamer.Time;
with SAM.DMAC; use SAM.DMAC;
with SAM.DMAC.Sources;

with System.Machine_Code; use System.Machine_Code;

package body PyGamer.Screen is


   SPI : SAM.SERCOM.SPI.SPI_Device renames SAM.Device.SPI4;

   TFT_CS   : SAM.Port.GPIO_Point renames PB12;
   TFT_SCK  : SAM.Port.GPIO_Point renames PB13;
   TFT_MOSI : SAM.Port.GPIO_Point renames PB15;
   TFT_DC   : SAM.Port.GPIO_Point renames PB05;
   TFT_RST  : SAM.Port.GPIO_Point renames PA00;
   TFT_LITE : SAM.Port.GPIO_Point renames PA01;

   Device : ST7735R.ST7735R_Screen
     (Port => SPI'Access,
      CS   => TFT_CS'Access,
      RS   => TFT_DC'Access,
      RST  => TFT_RST'Access,
      Time => PyGamer.Time.HAL_Delay);

   procedure Initialize;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize is
   begin
      -- Clocks --

      SAM.Clock_Generator.Configure_Periph_Channel
        (SAM.Clock_Generator.IDs.SERCOM4_CORE, Clk_48Mhz);

      SAM.Clock_Generator.Configure_Periph_Channel
        (SAM.Clock_Generator.IDs.SERCOM4_SLOW, Clk_32Khz);

      SAM.Main_Clock.SERCOM4_On;

      -- SPI --

      SPI.Configure
        (Baud                => 1,
         Data_Order          => SAM.SERCOM.SPI.Most_Significant_First,
         Phase               => SAM.SERCOM.SPI.Sample_Leading_Edge,
         Polarity            => SAM.SERCOM.SPI.Active_High,
         DIPO                => 0,
         DOPO                => 2,
         Slave_Select_Enable => False);

      SPI.Debug_Stop_Mode (Enabled => True);

      SPI.Enable;

      -- IOs --

      TFT_LITE.Set_Mode (HAL.GPIO.Output);
      TFT_CS.Set_Mode (HAL.GPIO.Output);
      TFT_RST.Set_Mode (HAL.GPIO.Output);
      TFT_DC.Set_Mode (HAL.GPIO.Output);

      TFT_SCK.Clear;
      TFT_SCK.Set_Mode (HAL.GPIO.Output);
      TFT_SCK.Set_Pull_Resistor (HAL.GPIO.Floating);
      TFT_SCK.Set_Function (SAM.Functions.PB13_SERCOM4_PAD1);

      TFT_MOSI.Clear;
      TFT_MOSI.Set_Mode (HAL.GPIO.Output);
      TFT_MOSI.Set_Pull_Resistor (HAL.GPIO.Floating);
      TFT_MOSI.Set_Function (SAM.Functions.PB15_SERCOM4_PAD3);

      TFT_LITE.Set;

      -- Screen --

      Device.Initialize;

      Set_Memory_Data_Access
        (LCD                 => Device,
         Color_Order         => RGB_Order,
         Vertical            => Vertical_Refresh_Top_Bottom,
         Horizontal          => Horizontal_Refresh_Left_Right,
         Row_Addr_Order      => Row_Address_Bottom_Top,
         Column_Addr_Order   => Column_Address_Left_Right,
         Row_Column_Exchange => True);

      Device.Set_Pixel_Format (Pixel_16bits);

      Device.Set_Frame_Rate_Normal (RTN         => 16#01#,
                                    Front_Porch => 16#2C#,
                                    Back_Porch  => 16#2D#);
      Device.Set_Frame_Rate_Idle (RTN         => 16#01#,
                                  Front_Porch => 16#2C#,
                                  Back_Porch  => 16#2D#);
      Device.Set_Frame_Rate_Partial_Full (RTN_Part         => 16#01#,
                                          Front_Porch_Part => 16#2C#,
                                          Back_Porch_Part  => 16#2D#,
                                          RTN_Full         => 16#01#,
                                          Front_Porch_Full => 16#2C#,
                                          Back_Porch_Full  => 16#2D#);
      Device.Set_Inversion_Control (Normal       => Line_Inversion,
                                    Idle         => Line_Inversion,
                                    Full_Partial => Line_Inversion);
      Device.Set_Power_Control_1 (AVDD => 2#101#,    --  5
                                  VRHP => 2#0_0010#, --  4.6
                                  VRHN => 2#0_0010#, --  -4.6
                                  MODE => 2#10#);    --  AUTO

      Device.Set_Power_Control_2 (VGH25 => 2#11#,  --  2.4
                                  VGSEL => 2#01#,  --  3*AVDD
                                  VGHBT => 2#01#); --  -10

      Device.Set_Power_Control_3 (16#0A#, 16#00#);
      Device.Set_Power_Control_4 (16#8A#, 16#2A#);
      Device.Set_Power_Control_5 (16#8A#, 16#EE#);
      Device.Set_Vcom (16#E#);

      Device.Set_Address (X_Start => 0,
                          X_End   => Width - 1,
                          Y_Start => 0,
                          Y_End   => Height - 1);

      Device.Turn_On;

      Device.Initialize_Layer (Layer  => 1,
                               Mode   => HAL.Bitmap.RGB_565,
                               X      => 0,
                               Y      => 0,
                               Width  => Width,
                               Height => Height);

      Device.Start_Pixel_Write;


      -- DMA --

      Configure (DMA_Screen_SPI,
                 Trig_Src       => SAM.DMAC.Sources.SERCOM4_TX,
                 Trig_Action    => Burst,
                 Priority       => 0,
                 Burst_Len      => 1,
                 Threshold      => BEAT_1,
                 Run_In_Standby => False);

      --  Only enable the channel 0 interrupt
      Enable (DMA_Screen_SPI, Transfer_Complete);

      --  The interrupt is only used to get out of a Wait For Interrupt loop, no
      --  handler is needed and therefore we should not enable the interrupt on
      --  the NVIC. Or do we?
      --
      --  Cortex_M.NVIC.Enable_Interrupt (SAM.Interrupt_Names.DMAC_TCMPL_2_IRQn);

      Configure_Descriptor (DMA_Descs (DMA_Screen_SPI),
                            Valid           => True,
                            Event_Output    => Disable,
                            Block_Action    => Interrupt,
                            Beat_Size       => B_8bit,
                            Src_Addr_Inc    => True,
                            Dst_Addr_Inc    => False,
                            Step_Selection  => Source,
                            Step_Size       => X1);
   end Initialize;

   -----------------
   -- Set_Address --
   -----------------

   procedure Set_Address (X_Start, X_End, Y_Start, Y_End : HAL.UInt16) is
   begin
      Device.Set_Address (X_Start, X_End, Y_Start, Y_End);
   end Set_Address;

   --------------------
   -- Start_Pixel_TX --
   --------------------

   procedure Start_Pixel_TX is
   begin
      Device.Start_Pixel_Write;

      --  Start transaction
      TFT_CS.Clear;

      --  Set data mode
      TFT_DC.Set;
   end Start_Pixel_TX;

   ------------------
   -- End_Pixel_TX --
   ------------------

   procedure End_Pixel_TX is
   begin
      --  End transaction
      TFT_CS.Set;
   end End_Pixel_TX;

   -----------------
   -- Push_Pixels --
   -----------------

   procedure Push_Pixels (Addr : System.Address; Len : Natural) is
   begin
      Start_DMA (Addr, Len);
      Wait_End_Of_DMA;
   end Push_Pixels;

   -----------------
   -- Push_Pixels --
   -----------------

   procedure Push_Pixels_Swap (Addr : System.Address; Len : Natural) is
      Data_8b : HAL.UInt8_Array (1 .. Len * 2)
        with Address => Addr;
      Index : Natural := Data_8b'First + 1;
      Tmp   : UInt8;

   begin
      while Index <= Data_8b'Last loop
         Tmp := Data_8b (Index);
         Data_8b (Index) := Data_8b (Index - 1);
         Data_8b (Index - 1) := Tmp;
         Index := Index + 1;
      end loop;

      Start_DMA (Data_8b'Address, Len);
      Wait_End_Of_DMA;
   end Push_Pixels_Swap;

   ------------
   -- Buffer --
   ------------

   function Buffer return HAL.Bitmap.Any_Bitmap_Buffer
   is (Device.Hidden_Buffer (1));

   ------------
   -- Update --
   ------------

   procedure Update is
   begin
      Device.Update_Layers;
   end Update;

   ------------
   -- Scroll --
   ------------

   procedure Scroll (Val : HAL.UInt8) is
   begin
      Device.Scroll (Val);
   end Scroll;

   ---------------
   -- Start_DMA --
   ---------------

   procedure Start_DMA (Addr : System.Address; Len : Natural) is
   begin
      Clear (DMA_Screen_SPI, Transfer_Complete);

      Set_Data_Transfer (DMA_Descs (DMA_Screen_SPI),
                         Block_Transfer_Count => UInt16 (Len * 2),
                         Src_Addr             => Addr,
                         Dst_Addr             => SPI.Data_Address);

      Enable (DMA_Screen_SPI);

   end Start_DMA;

   ---------------------
   -- Wait_End_Of_DMA --
   ---------------------

   procedure Wait_End_Of_DMA is
   begin
      --  Wait for the end of the data transfer
      while not SAM.DMAC.Set (DMA_Screen_SPI, SAM.DMAC.Transfer_Complete) loop
         Asm (Template => "wfi", -- Wait for interrupt
              Volatile => True);
      end loop;
   end Wait_End_Of_DMA;

begin
   Initialize;
end PyGamer.Screen;
