(* closure.sml
 *
 * COPYRIGHT (c) 2008 The Manticore Project (http://manticore.cs.uchicago.edu)
 * All rights reserved.
 *)

structure Closure : sig

    val convert : CPS.module -> CFG.module

  end = struct

    structure ConvertStyle =
       struct
          datatype style = Flat | FlatWithCFA
          fun toString Flat = "flat"
	    | toString FlatWithCFA = "flatWithCFA"
          fun fromString "flat" = SOME Flat
	    | fromString "flatWithCFA" = SOME FlatWithCFA
	    | fromString _ = NONE
          val cvt = {
		  tyName = "convertStyle",
		  fromString = fromString,
		  toString = toString
		}
       end

    val convertStyle = Controls.genControl {
            name = "convert-style",
            pri = [5, 0],
            obscurity = 1,
            help = "closure convert style",
            default = ConvertStyle.Flat
          }

    val () = ControlRegistry.register ClosureControls.registry {
            ctl = Controls.stringControl ConvertStyle.cvt convertStyle,
            envName = NONE
          }

    fun convert cps = (case Controls.get convertStyle
	   of ConvertStyle.Flat => FlatClosure.convert cps
	    | ConvertStyle.FlatWithCFA => FlatClosureWithCFA.convert cps
	  (* end case *))

    val convert = BasicControl.mkKeepPass {
	    preOutput = PrintCPS.output,
            preExt = "cps",
            postOutput = PrintCFG.output {types=true},
            postExt = "cfg",
            passName = "closure",
            pass = convert,
            registry = ClosureControls.registry
	  }

  end
