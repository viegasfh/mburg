IMPLEMENTATION MODULE -->modulename;

(* This is a modified version for Mburg --- it computes column positions *)
(* Scanner generated by Coco/R *)

IMPORT FileIO, Storage, Strings, Ascii;
FROM Types IMPORT LONGINT; (* for gpm version *)

CONST
  noSym   = -->unknownsym; (*error token code*)
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
    -->comment
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
      -->literals
    END CheckLiteral;

  BEGIN (*Get*)
    -->GetSy1
    pos := nextPos;   nextPos := bp;
    col := nextCol;   nextCol := spaces;
    line := nextLine; nextLine := curLine;
    len := nextLen;   nextLen := 0;
    apx := VAL(LONGINT, 0); state := start[ORD(ch)]; bp0 := bp;
    LOOP
      NextCh; INC(nextLen);
      CASE state OF
      -->GetSy2
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
  -->initializations
  Error := Err; LBlkSize := VAL(LONGINT, BlkSize);
END -->modulename.
-->definitionDEFINITION MODULE -->modulename;

(* Scanner generated by Coco/R *)

IMPORT FileIO;
FROM Types IMPORT LONGINT; (* for gpm version *)

VAR
  src, lst:    FileIO.File;  (*source/list files. To be opened by the main pgm*)
  directory:   ARRAY [0 .. 63] OF CHAR (*of source file*);
  line, col:   INTEGER;      (*line and column of current symbol*)
  len:         CARDINAL;     (*length of current symbol*)
  pos:         LONGINT;      (*file position of current symbol*)
  nextLine:    INTEGER;      (*line of lookahead symbol*)
  nextCol:     INTEGER;      (*column of lookahead symbol*)
  nextLen:     CARDINAL;     (*length of lookahead symbol*)
  nextPos:     LONGINT;      (*file position of lookahead symbol*)
  errors:      INTEGER;      (*number of detected errors*)
  Error:       PROCEDURE ((*nr*)INTEGER, (*line*)INTEGER, (*col*)INTEGER,
                          (*pos*)LONGINT);

PROCEDURE Get (VAR sym: CARDINAL);
(* Gets next symbol from source file *)

PROCEDURE GetString (pos: LONGINT; len: CARDINAL; VAR name: ARRAY OF CHAR);
(* Retrieves exact string of max length len from position pos in source file *)

PROCEDURE GetName (pos: LONGINT; len: CARDINAL; VAR name: ARRAY OF CHAR);
(* Retrieves name of symbol of length len at position pos in source file *)

PROCEDURE CharAt (pos: LONGINT): CHAR;
(* Returns exact character at position pos in source file *)

PROCEDURE Reset;
(* Reads and stores source file internally *)

PROCEDURE SkipAndGetLine(i : CARDINAL;		(* indent to skip *)
			 e : INTEGER;		(* end file-pos   *)
		     VAR p : INTEGER;		(* crnt file-pos  *)
		     VAR l : CARDINAL;		(* fetched length *)
		     VAR s : ARRAY OF CHAR);	(* output string  *)

END -->modulename.
