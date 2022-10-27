IMPLEMENTATION MODULE MburgS;

FROM  MburgG  IMPORT 
  EOFSYM, identifierSym, numberSym, stringSym, HEADERSym, DECLARATIONSSym, 
  RULESSym, ENDRULESSym, percentstartSym, percentOPSym, percentNEWSym, 
  percentENUMSym, percentLEFTSym, percentRIGHTSym, percentSTATESym, 
  percentMNAMESym, percentTNAMESym, percentATTRSym, lessSym, greaterSym, 
  percentFORMSym, percenttermSym, equalSym, pointSym, lparenpointSym, 
  pointrparenSym, lparenSym, commaSym, rparenSym, andSym, NOSYM;

(* This is a modified version for Mburg --- it computes column positions *)
(* Scanner generated by Coco/R *)

IMPORT FileIO, Storage, Strings, Ascii;
FROM Types IMPORT LONGINT; (* for gpm version *)

CONST
  noSym   = NOSYM; (*error token code*)
  (* not only for errors but also for not finished states of scanner analysis *)
  eof     = 32C (*MS-DOS eof*);
  EOF     = FileIO.EOF;
  EOL     = FileIO.LF;
  BlkSize = 16384;
TYPE
  BufBlock   = ARRAY [0 .. BlkSize-1] OF CHAR;
  Buffer     = ARRAY [0 .. 31] OF POINTER TO BufBlock;
  StartTable = ARRAY [0 .. 255] OF INTEGER;
  GetCH      = PROCEDURE (LONGINT) : CHAR;
VAR
  ch:        CHAR;       (*current input character*)
  curLine:   INTEGER;    (*current input line (may be higher than line)*)
  lineStart: LONGINT;    (*start position of current line*)
  apx:       LONGINT;    (*length of appendix (CONTEXT phrase)*)
  oldEols:   INTEGER;    (*number of EOLs in a comment*)
  bp, bp0:   LONGINT;    (*current position in buf
                           (bp0: position of current token)*)
  LBlkSize:  LONGINT;    (*BlkSize*)
  inputLen:  LONGINT;    (*source file size*)
  buf:       Buffer;     (*source buffer for low-level access*)
  start:     StartTable; (*start state for every character*)
  CurrentCh: GetCH;

  spaces:    CARDINAL;   (* ############# NEW ############## *)

PROCEDURE Err (nr, line, col: INTEGER; pos: LONGINT);
  BEGIN
    INC(errors)
  END Err;

  (*#check(overflow=>off)*)

PROCEDURE NextCh;
(* Return global variable ch *)
  BEGIN
    INC(bp); ch := CurrentCh(bp);
    IF ch = Ascii.ht THEN 
      INC(spaces,8); DEC(spaces,spaces MOD 8);
    ELSE
      INC(spaces);
    END;
    IF ch = EOL THEN INC(curLine); lineStart := bp; spaces := 0 END
  END NextCh;

PROCEDURE Comment (): BOOLEAN;
  VAR
    level, startLine: INTEGER;
    oldLineStart : LONGINT;
  BEGIN
    level := 1; startLine := curLine; oldLineStart := lineStart;
    IF (ch = "-") THEN
      NextCh;
      IF (ch = "-") THEN
        NextCh;
        LOOP
          IF (ch = CHR(10)) THEN
            DEC(level); oldEols := curLine - startLine; NextCh;
            IF level = 0 THEN RETURN TRUE END;
          ELSIF ch = EOF THEN RETURN FALSE
          ELSE NextCh END;
        END; (* LOOP *)
      ELSE
        IF ch = EOL THEN DEC(curLine); lineStart := oldLineStart END;
        DEC(bp, 2); NextCh; RETURN FALSE
      END;
    END;
    RETURN FALSE;
  END Comment;

PROCEDURE Get (VAR sym: CARDINAL);
  VAR
    state: CARDINAL;

  PROCEDURE Equal (s: ARRAY OF CHAR): BOOLEAN;
    VAR
      i: CARDINAL;
      q: LONGINT;
    BEGIN
      IF nextLen # Strings.Length(s) THEN RETURN FALSE END;
      i := 1; q := bp0; INC(q);
      WHILE i < nextLen DO
        IF CurrentCh(q) # s[i] THEN RETURN FALSE END;
        INC(i); INC(q)
      END;
      RETURN TRUE
    END Equal;

  PROCEDURE CheckLiteral;
    BEGIN
      CASE CurrentCh(bp0) OF
        "%": IF Equal("%ATTR") THEN sym := percentATTRSym; 
             ELSIF Equal("%ENUM") THEN sym := percentENUMSym; 
             ELSIF Equal("%FORM") THEN sym := percentFORMSym; 
             ELSIF Equal("%LEFT") THEN sym := percentLEFTSym; 
             ELSIF Equal("%MNAME") THEN sym := percentMNAMESym; 
             ELSIF Equal("%NEW") THEN sym := percentNEWSym; 
             ELSIF Equal("%OP") THEN sym := percentOPSym; 
             ELSIF Equal("%RIGHT") THEN sym := percentRIGHTSym; 
             ELSIF Equal("%STATE") THEN sym := percentSTATESym; 
             ELSIF Equal("%TNAME") THEN sym := percentTNAMESym; 
             ELSIF Equal("%start") THEN sym := percentstartSym; 
             ELSIF Equal("%term") THEN sym := percenttermSym; 
             END
      | "D": IF Equal("DECLARATIONS") THEN sym := DECLARATIONSSym; 
             END
      | "E": IF Equal("ENDRULES") THEN sym := ENDRULESSym; 
             END
      | "H": IF Equal("HEADER") THEN sym := HEADERSym; 
             END
      | "R": IF Equal("RULES") THEN sym := RULESSym; 
             END
      ELSE
      END
    END CheckLiteral;

  BEGIN (*Get*)
    WHILE (ch=' ') OR
          (ch >= CHR(1)) & (ch <= CHR(31)) DO NextCh END;
    IF ((ch = "-")) & Comment() THEN Get(sym); RETURN END;
    pos := nextPos;   nextPos := bp;
    col := nextCol;   nextCol := spaces;
    line := nextLine; nextLine := curLine;
    len := nextLen;   nextLen := 0;
    apx := VAL(LONGINT, 0); state := start[ORD(ch)]; bp0 := bp;
    LOOP
      NextCh; INC(nextLen);
      CASE state OF
         1: IF (ch >= "0") & (ch <= "9") OR
               (ch >= "A") & (ch <= "Z") OR
               (ch = "_") OR
               (ch >= "a") & (ch <= "z") THEN 
            ELSE sym := identifierSym; CheckLiteral; RETURN
            END;
      |  2: IF (ch >= "0") & (ch <= "9") THEN 
            ELSE sym := numberSym; RETURN
            END;
      |  3: IF (ch <= CHR(9)) OR
               (ch >= CHR(11)) & (ch <= "!") OR
               (ch>="#") THEN 
            ELSIF (ch = '"') THEN state := 4; 
            ELSE sym := noSym; RETURN
            END;
      |  4: sym := stringSym; RETURN
      |  5: IF (ch <= CHR(9)) OR
               (ch >= CHR(11)) & (ch <= "&") OR
               (ch>="(") THEN 
            ELSIF (ch = "'") THEN state := 4; 
            ELSE sym := noSym; RETURN
            END;
      |  6: sym := lessSym; RETURN
      |  7: sym := greaterSym; RETURN
      |  8: sym := equalSym; RETURN
      |  9: IF (ch = ")") THEN state := 12; 
            ELSE sym := pointSym; RETURN
            END;
      | 10: IF (ch = ".") THEN state := 11; 
            ELSE sym := lparenSym; RETURN
            END;
      | 11: sym := lparenpointSym; RETURN
      | 12: sym := pointrparenSym; RETURN
      | 13: sym := commaSym; RETURN
      | 14: sym := rparenSym; RETURN
      | 15: sym := andSym; RETURN
      | 16: sym := EOFSYM; ch := 0C; DEC(bp); RETURN
      ELSE sym := noSym; RETURN (*NextCh already done*)
      END
    END
  END Get;

PROCEDURE SkipAndGetLine(i : CARDINAL;		(* indent to skip *)
			 e : INTEGER;		(* end file-pos   *)
		     VAR p : INTEGER;		(* crnt file-pos  *)
		     VAR l : CARDINAL;		(* fetched length *)
		     VAR s : ARRAY OF CHAR);	(* output string  *)
  VAR 
    ch : CHAR;
    ix : CARDINAL;
    sp : CARDINAL;
  BEGIN
    sp := 0;
    ch := CharAt(p); INC(p);
   (* skip i positions if possible *)
    WHILE (sp < i) AND (ch <= " ") AND (p <= e) AND (ch <> Ascii.lf) DO
      IF ch = Ascii.ht THEN INC(sp,8); DEC(sp,sp MOD 8) ELSE INC(sp) END;
      ch := CharAt(p); INC(p); 
    END;
    ix := 0;
    WHILE sp > i DO
      s[ix] := " "; INC(ix); DEC(sp);
    END;
    WHILE (p <= e) AND (ch <> Ascii.lf) DO
      s[ix] := ch; INC(ix);
      ch := CharAt(p); INC(p);
    END;
    s[ix] := ""; l := ix;
  END SkipAndGetLine;

PROCEDURE GetString (pos: LONGINT; len: CARDINAL; VAR s: ARRAY OF CHAR);
  VAR
    i: CARDINAL;
    p: LONGINT;
  BEGIN
    IF len > HIGH(s) THEN len := HIGH(s) END;
    p := pos; i := 0;
    WHILE i < len DO
      s[i] := CharAt(p); INC(i); INC(p)
    END;
    s[len] := 0C;
  END GetString;

PROCEDURE GetName (pos: LONGINT; len: CARDINAL; VAR s: ARRAY OF CHAR);
  VAR
    i: CARDINAL;
    p: LONGINT;
  BEGIN
    IF len > HIGH(s) THEN len := HIGH(s) END;
    p := pos; i := 0;
    WHILE i < len DO
      s[i] := CurrentCh(p); INC(i); INC(p)
    END;
    s[len] := 0C;
  END GetName;

PROCEDURE CharAt (pos: LONGINT): CHAR;
  VAR
    ch : CHAR;
  BEGIN
    IF pos >= inputLen THEN RETURN FileIO.EOF END;
    ch := buf[VAL(CARDINAL,pos DIV LBlkSize)]^[VAL(CARDINAL,pos MOD LBlkSize)];
    IF ch # eof THEN RETURN ch ELSE RETURN FileIO.EOF END
  END CharAt;

PROCEDURE CapChAt (pos: LONGINT): CHAR;
  VAR
    ch : CHAR;
  BEGIN
    IF pos >= inputLen THEN RETURN FileIO.EOF END;
    ch := CAP(buf[VAL(CARDINAL,pos DIV LBlkSize)]^[VAL(CARDINAL,pos MOD LBlkSize)]);
    IF ch # eof THEN RETURN ch ELSE RETURN FileIO.EOF END
  END CapChAt;

PROCEDURE Reset;
  VAR
    len: LONGINT;
    i, read: CARDINAL;
  BEGIN (*assert: src has been opened*)
    len := FileIO.Length(src); i := 0; inputLen := len;
    WHILE len > LBlkSize DO
      Storage.ALLOCATE(buf[i], BlkSize);
      read := BlkSize; FileIO.ReadBytes(src, buf[i]^, read);
      len := len - VAL(LONGINT, read); INC(i)
    END;
    Storage.ALLOCATE(buf[i], VAL(CARDINAL, len)+1);
    read := VAL(CARDINAL, len); FileIO.ReadBytes(src, buf[i]^, read);
    buf[i]^[read] := EOF;
    curLine := 1; lineStart := VAL(LONGINT, -2); bp := VAL(LONGINT, -1);
    oldEols := 0; apx := VAL(LONGINT, 0); errors := 0;
    spaces := 0; (* # new # *)
    NextCh;
  END Reset;

BEGIN
  CurrentCh := CharAt;
  start[  0] := 16; start[  1] := 17; start[  2] := 17; start[  3] := 17; 
  start[  4] := 17; start[  5] := 17; start[  6] := 17; start[  7] := 17; 
  start[  8] := 17; start[  9] := 17; start[ 10] := 17; start[ 11] := 17; 
  start[ 12] := 17; start[ 13] := 17; start[ 14] := 17; start[ 15] := 17; 
  start[ 16] := 17; start[ 17] := 17; start[ 18] := 17; start[ 19] := 17; 
  start[ 20] := 17; start[ 21] := 17; start[ 22] := 17; start[ 23] := 17; 
  start[ 24] := 17; start[ 25] := 17; start[ 26] := 17; start[ 27] := 17; 
  start[ 28] := 17; start[ 29] := 17; start[ 30] := 17; start[ 31] := 17; 
  start[ 32] := 17; start[ 33] := 17; start[ 34] :=  3; start[ 35] := 17; 
  start[ 36] :=  1; start[ 37] :=  1; start[ 38] := 15; start[ 39] :=  5; 
  start[ 40] := 10; start[ 41] := 14; start[ 42] := 17; start[ 43] := 17; 
  start[ 44] := 13; start[ 45] := 17; start[ 46] :=  9; start[ 47] := 17; 
  start[ 48] :=  2; start[ 49] :=  2; start[ 50] :=  2; start[ 51] :=  2; 
  start[ 52] :=  2; start[ 53] :=  2; start[ 54] :=  2; start[ 55] :=  2; 
  start[ 56] :=  2; start[ 57] :=  2; start[ 58] := 17; start[ 59] := 17; 
  start[ 60] :=  6; start[ 61] :=  8; start[ 62] :=  7; start[ 63] := 17; 
  start[ 64] := 17; start[ 65] :=  1; start[ 66] :=  1; start[ 67] :=  1; 
  start[ 68] :=  1; start[ 69] :=  1; start[ 70] :=  1; start[ 71] :=  1; 
  start[ 72] :=  1; start[ 73] :=  1; start[ 74] :=  1; start[ 75] :=  1; 
  start[ 76] :=  1; start[ 77] :=  1; start[ 78] :=  1; start[ 79] :=  1; 
  start[ 80] :=  1; start[ 81] :=  1; start[ 82] :=  1; start[ 83] :=  1; 
  start[ 84] :=  1; start[ 85] :=  1; start[ 86] :=  1; start[ 87] :=  1; 
  start[ 88] :=  1; start[ 89] :=  1; start[ 90] :=  1; start[ 91] := 17; 
  start[ 92] := 17; start[ 93] := 17; start[ 94] := 17; start[ 95] :=  1; 
  start[ 96] := 17; start[ 97] :=  1; start[ 98] :=  1; start[ 99] :=  1; 
  start[100] :=  1; start[101] :=  1; start[102] :=  1; start[103] :=  1; 
  start[104] :=  1; start[105] :=  1; start[106] :=  1; start[107] :=  1; 
  start[108] :=  1; start[109] :=  1; start[110] :=  1; start[111] :=  1; 
  start[112] :=  1; start[113] :=  1; start[114] :=  1; start[115] :=  1; 
  start[116] :=  1; start[117] :=  1; start[118] :=  1; start[119] :=  1; 
  start[120] :=  1; start[121] :=  1; start[122] :=  1; start[123] := 17; 
  start[124] := 17; start[125] := 17; start[126] := 17; start[127] := 17; 
  start[128] := 17; start[129] := 17; start[130] := 17; start[131] := 17; 
  start[132] := 17; start[133] := 17; start[134] := 17; start[135] := 17; 
  start[136] := 17; start[137] := 17; start[138] := 17; start[139] := 17; 
  start[140] := 17; start[141] := 17; start[142] := 17; start[143] := 17; 
  start[144] := 17; start[145] := 17; start[146] := 17; start[147] := 17; 
  start[148] := 17; start[149] := 17; start[150] := 17; start[151] := 17; 
  start[152] := 17; start[153] := 17; start[154] := 17; start[155] := 17; 
  start[156] := 17; start[157] := 17; start[158] := 17; start[159] := 17; 
  start[160] := 17; start[161] := 17; start[162] := 17; start[163] := 17; 
  start[164] := 17; start[165] := 17; start[166] := 17; start[167] := 17; 
  start[168] := 17; start[169] := 17; start[170] := 17; start[171] := 17; 
  start[172] := 17; start[173] := 17; start[174] := 17; start[175] := 17; 
  start[176] := 17; start[177] := 17; start[178] := 17; start[179] := 17; 
  start[180] := 17; start[181] := 17; start[182] := 17; start[183] := 17; 
  start[184] := 17; start[185] := 17; start[186] := 17; start[187] := 17; 
  start[188] := 17; start[189] := 17; start[190] := 17; start[191] := 17; 
  start[192] := 17; start[193] := 17; start[194] := 17; start[195] := 17; 
  start[196] := 17; start[197] := 17; start[198] := 17; start[199] := 17; 
  start[200] := 17; start[201] := 17; start[202] := 17; start[203] := 17; 
  start[204] := 17; start[205] := 17; start[206] := 17; start[207] := 17; 
  start[208] := 17; start[209] := 17; start[210] := 17; start[211] := 17; 
  start[212] := 17; start[213] := 17; start[214] := 17; start[215] := 17; 
  start[216] := 17; start[217] := 17; start[218] := 17; start[219] := 17; 
  start[220] := 17; start[221] := 17; start[222] := 17; start[223] := 17; 
  start[224] := 17; start[225] := 17; start[226] := 17; start[227] := 17; 
  start[228] := 17; start[229] := 17; start[230] := 17; start[231] := 17; 
  start[232] := 17; start[233] := 17; start[234] := 17; start[235] := 17; 
  start[236] := 17; start[237] := 17; start[238] := 17; start[239] := 17; 
  start[240] := 17; start[241] := 17; start[242] := 17; start[243] := 17; 
  start[244] := 17; start[245] := 17; start[246] := 17; start[247] := 17; 
  start[248] := 17; start[249] := 17; start[250] := 17; start[251] := 17; 
  start[252] := 17; start[253] := 17; start[254] := 17; start[255] := 17; 
  Error := Err; LBlkSize := VAL(LONGINT, BlkSize);
END MburgS.
