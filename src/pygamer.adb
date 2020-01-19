with System;
with System.Storage_Elements;

with SAM.Main_Clock;
with SAM.DMAC;

with HAL;

package body PyGamer is

   System_Vectors : constant HAL.UInt32;
   pragma Import (Asm, System_Vectors, "__vectors");

   VTOR : System.Address
     with Volatile,
     Address => System.Storage_Elements.To_Address (16#E000_ED08#);

   procedure Unknown_Interrupt;
   pragma Export (C, Unknown_Interrupt, "__unknown_interrupt_handler");

   -----------------------
   -- Unknown_Interrupt --
   -----------------------

   procedure Unknown_Interrupt is
   begin
      raise Program_Error;
   end Unknown_Interrupt;

begin

   --  Set the vector table address
   VTOR := System_Vectors'Address;

   --  Setup the clock system
   SAM.Clock_Setup_120Mhz.Initialize_Clocks;

   --  Turn on and enable DMAC
   SAM.Main_Clock.DMAC_On;
   SAM.DMAC.Enable (DMA_Descs'Access, DMA_WB'Access);

end PyGamer;
