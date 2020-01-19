with System;
with Interfaces;   use Interfaces;
with Interfaces.C; use Interfaces.C;

with HAL.GPIO;

with SAM.Clock_Generator.IDs;
with SAM.Main_Clock;
with SAM.DAC; use SAM.DAC;
with SAM.Device;
with SAM.DMAC; use SAM.DMAC;
with SAM.DMAC.Sources;
with SAM.TC; use SAM.TC;
with SAM.Interrupt_Names;

with Cortex_M.NVIC;

with HAL; use HAL;

package body PyGamer.Audio is

   User_Callback : Audio_Callback := null;

   Buffer_Size : constant := 64;

   Buffer_Left_0 : Data_Array (1 .. Buffer_Size);
   Buffer_Left_1 : Data_Array (1 .. Buffer_Size);
   Buffer_Right_0 : Data_Array (1 .. Buffer_Size);
   Buffer_Right_1 : Data_Array (1 .. Buffer_Size);

   Flip : Boolean := False;

   procedure DMA_Int_Handler;
   pragma Export (C, DMA_Int_Handler, "__dmac_tcmpl_0_handler");

   ---------------------
   -- DMA_Int_Handler --
   ---------------------

   procedure DMA_Int_Handler is
      Buffer_0 : System.Address := (if Flip
                                    then Buffer_Left_0'Address
                                    else Buffer_Left_1'Address);

      Buffer_1 : System.Address := (if Flip
                                    then Buffer_Right_0'Address
                                    else Buffer_Right_1'Address);
   begin
      Cortex_M.NVIC.Clear_Pending (SAM.Interrupt_Names.dmac_0_interrupt);

      Clear (DMA_DAC_0, Transfer_Complete);
      Clear (DMA_DAC_1, Transfer_Complete);

      Set_Data_Transfer (DMA_Descs (DMA_DAC_0),
                         Block_Transfer_Count => Buffer_Left_0'Length,
                         Src_Addr             => Buffer_0,
                         Dst_Addr             => SAM.DAC.Data_Address (0));
      Set_Data_Transfer (DMA_Descs (DMA_DAC_1),
                         Block_Transfer_Count => Buffer_Right_0'Length,
                         Src_Addr             => Buffer_1,
                         Dst_Addr             => SAM.DAC.Data_Address (1));

      Enable (DMA_DAC_0);
      Enable (DMA_DAC_1);

      if User_Callback /= null then
         if Flip then
            User_Callback (Buffer_Left_1, Buffer_Right_1);
         else
            User_Callback (Buffer_Left_0, Buffer_Right_0);
         end if;
      else
         if Flip then
            Buffer_Left_1 := (others => 0);
            Buffer_Right_1 := (others => 0);
         else
            Buffer_Left_0 := (others => 0);
            Buffer_Right_0 := (others => 0);
         end if;
      end if;

      Flip := not Flip;
   end DMA_Int_Handler;

   ------------------
   -- Set_Callback --
   ------------------

   procedure Set_Callback (Callback    : Audio_Callback;
                           Sample_Rate : Sample_Rate_Kind)
   is
   begin
      User_Callback := Callback;

      --  Set the timer period coresponding to the requested sample rate
      SAM.Device.TC0.Set_Period
        (case Sample_Rate is
            when SR_11025 => UInt8 ((UInt32 (48000000) / 64) / 11025),
            when SR_22050 => UInt8 ((UInt32 (48000000) / 64) / 22050),
            when SR_44100 => UInt8 ((UInt32 (48000000) / 64) / 44100),
            when SR_96000 => UInt8 ((UInt32 (48000000) / 64) / 96000));
   end Set_Callback;

begin

   -- DAC --

   SAM.Clock_Generator.Configure_Periph_Channel
     (SAM.Clock_Generator.IDs.DAC, Clk_48Mhz);

   SAM.Main_Clock.DAC_On;

   SAM.DAC.Configure (Single_Mode, VREFAB);

   Debug_Stop_Mode (False);

   Configure_Channel (Chan                           => 0,
                      Oversampling                   => OSR_16,
                      Refresh                        => 0,
                      Enable_Dithering               => True,
                      Run_In_Standby                 => True,
                      Standalone_Filter              => False,
                      Current                        => CC1M,
                      Adjustement                    => Right_Adjusted,
                      Enable_Filter_Result_Ready_Evt => False,
                      Enable_Data_Buffer_Empty_Evt   => False,
                      Enable_Convert_On_Input_Evt    => False,
                      Invert_Input_Evt               => False,
                      Enable_Overrun_Int             => False,
                      Enable_Underrun_Int            => False,
                      Enable_Result_Ready_Int        => False,
                      Enable_Buffer_Empty_Int        => False);

   Configure_Channel (Chan                           => 1,
                      Oversampling                   => OSR_16,
                      Refresh                        => 0,
                      Enable_Dithering               => True,
                      Run_In_Standby                 => True,
                      Standalone_Filter              => False,
                      Current                        => CC1M,
                      Adjustement                    => Right_Adjusted,
                      Enable_Filter_Result_Ready_Evt => False,
                      Enable_Data_Buffer_Empty_Evt   => False,
                      Enable_Convert_On_Input_Evt    => False,
                      Invert_Input_Evt               => False,
                      Enable_Overrun_Int             => False,
                      Enable_Underrun_Int            => False,
                      Enable_Result_Ready_Int        => False,
                      Enable_Buffer_Empty_Int        => False);

   Enable (Chan_0 => True,
           Chan_1 => True);

   -- Enable speaker --

   SAM.Device.PA27.Set_Mode (HAL.GPIO.Output);
   SAM.Device.PA27.Set;

   -- DMA --

   Configure (DMA_DAC_0,
              Trig_Src       => SAM.DMAC.Sources.TC0_OVF,
              Trig_Action    => Burst,
              Priority       => 1,
              Burst_Len      => 1,
              Threshold      => BEAT_1,
              Run_In_Standby => False);

   --  Only enable the channel 0 interrupt
   Enable (DMA_DAC_0, Transfer_Complete);
   Cortex_M.NVIC.Enable_Interrupt (SAM.Interrupt_Names.dmac_0_interrupt);

   Configure (DMA_DAC_1,
              Trig_Src       => SAM.DMAC.Sources.TC0_OVF,
              Trig_Action    => Burst,
              Priority       => 1,
              Burst_Len      => 1,
              Threshold      => BEAT_1,
              Run_In_Standby => False);

   Configure_Descriptor (DMA_Descs (DMA_DAC_0),
                         Valid           => True,
                         Event_Output    => Disable,
                         Block_Action    => Interrupt,
                         Beat_Size       => B_16bit,
                         Src_Addr_Inc    => True,
                         Dst_Addr_Inc    => False,
                         Step_Selection  => Source,
                         Step_Size       => X1);

   Configure_Descriptor (DMA_Descs (DMA_DAC_1),
                         Valid           => True,
                         Event_Output    => Disable,
                         Block_Action    => Interrupt,
                         Beat_Size       => B_16bit,
                         Src_Addr_Inc    => True,
                         Dst_Addr_Inc    => False,
                         Step_Selection  => Source,
                         Step_Size       => X1);

   -- Timer --

   SAM.Clock_Generator.Configure_Periph_Channel
     (SAM.Clock_Generator.IDs.TC0, Clk_48Mhz);

   SAM.Main_Clock.TC0_On;

   SAM.Device.TC0.Configure (Mode             => TC_8bit,
                             Prescaler        => DIV64,
                             Run_In_Standby   => True,
                             Clock_On_Demand  => False,
                             Auto_Lock        => False,
                             Capture_0_Enable => False,
                             Capture_1_Enable => False,
                             Capture_0_On_Pin => False,
                             Capture_1_On_Pin => False,
                             Capture_0_Mode   => Default,
                             Capture_1_Mode   => Default);

   --  Start the time with the longest period to have a reduced number of
   --  interrupt until the audio is actually used.
   SAM.Device.TC0.Set_Period (255);

   SAM.Device.TC0.Enable;

   --  Start the first DMA transfer
   DMA_Int_Handler;

end PyGamer.Audio;
