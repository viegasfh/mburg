IMPLEMENTATION MODULE MburgP;

FROM  MburgG  IMPORT 
  EOFSYM, identifierSym, numberSym, stringSym, HEADERSym, DECLARATIONSSym, 
  RULESSym, ENDRULESSym, percentstartSym, percentOPSym, percentNEWSym, 
  percentENUMSym, percentLEFTSym, percentRIGHTSym, percentSTATESym, 
  percentMNAMESym, percentTNAMESym, percentATTRSym, lessSym, greaterSym, 
  percentFORMSym, percenttermSym, equalSym, pointSym, lparenpointSym, 
  pointrparenSym, lparenSym, commaSym, rparenSym, andSym, NOSYM;

(* Parser generated by Coco/R *)

IMPORT FileIO, MburgS;
FROM Types IMPORT LONGINT; (* for gpm version *)

IMPORT BurgInOut, BurgAst, CardSequences;

 (* ------------------------------------------------------- *)

  PROCEDURE GetNumber (VAR int : INTEGER);
  (* Convert latest token to integer value Int *)
    VAR
      i : CARDINAL;
      string : ARRAY [0 .. 20] OF CHAR;
    BEGIN
      MburgS.GetString(MburgS.pos, MburgS.len, string);
      i := 0; int := 0;
      WHILE string[i] # 0C DO
        int := 10 * int + VAL(INTEGER, ORD(string[i]) - ORD('0')); INC(i)
      END;
    END GetNumber;

 (* ------------------------------------------------------- *)



CONST 
  maxT = 30;
  minErrDist  =  2;  (* minimal distance (good tokens) between two errors *)
  setsize     = 16;  (* sets are stored in 16 bits *)

TYPE
  SymbolSet = ARRAY [0 .. maxT DIV setsize] OF BITSET;

VAR
  symSet:  ARRAY [0 ..   8] OF SymbolSet; (*symSet[0] = allSyncSyms*)
  errDist: CARDINAL;   (* number of symbols recognized since last error *)
  sym:     CARDINAL;   (* current input symbol *)

PROCEDURE  Error (errNo: INTEGER);
  BEGIN
    IF errDist >= minErrDist THEN
      MburgS.Error(errNo, MburgS.nextLine, MburgS.nextCol, MburgS.nextPos);
    END;
    errDist := 0;
  END Error;

PROCEDURE  Get;
  VAR
    s: ARRAY [0 .. 31] OF CHAR;
  BEGIN
    REPEAT
      MburgS.Get(sym);
      IF sym <= maxT THEN
        INC(errDist);
      ELSE
        
      END;
    UNTIL sym <= maxT
  END Get;

PROCEDURE  In (VAR s: SymbolSet; x: CARDINAL): BOOLEAN;
  BEGIN
    RETURN x MOD setsize IN s[x DIV setsize];
  END In;

PROCEDURE  Expect (n: CARDINAL);
  BEGIN
    IF sym = n THEN Get ELSE Error(n) END
  END Expect;

PROCEDURE  ExpectWeak (n, follow: CARDINAL);
  BEGIN
    IF sym = n
      THEN Get
      ELSE Error(n); WHILE ~ In(symSet[follow], sym) DO Get END
    END
  END ExpectWeak;

PROCEDURE  WeakSeparator (n, syFol, repFol: CARDINAL): BOOLEAN;
  VAR
    s: SymbolSet;
    i: CARDINAL;
  BEGIN
    IF sym = n
      THEN Get; RETURN TRUE
      ELSIF In(symSet[repFol], sym) THEN RETURN FALSE
      ELSE
        i := 0;
        WHILE i <= maxT DIV setsize DO
          s[i] := symSet[0, i] + symSet[syFol, i] + symSet[repFol, i]; INC(i)
        END;
        Error(n); WHILE ~ In(s, sym) DO Get END;
        RETURN In(symSet[syFol], sym)
    END
  END WeakSeparator;

PROCEDURE  BalancedPar;
  BEGIN
    Expect(lparenSym);
    WHILE In(symSet[1], sym) DO
      IF In(symSet[2], sym) THEN
        Get;
      ELSE
        BalancedPar;
      END;
    END;
    Expect(rparenSym);
  END BalancedPar;

PROCEDURE  SemAction (prod : BurgAst.ProdIndex);
  BEGIN
    Expect(lparenpointSym);
    IF (sym = lessSym) THEN
      Get;
      BurgAst.prodInfo[prod].decPos := MburgS.nextPos;
              BurgAst.prodInfo[prod].decCol := MburgS.nextCol;
      WHILE In(symSet[3], sym) DO
        Get;
      END;
      BurgAst.prodInfo[prod].decEnd := MburgS.pos + INT(MburgS.len);
      Expect(greaterSym);
      BurgAst.prodInfo[prod].semPos := MburgS.nextPos;
              BurgAst.prodInfo[prod].semCol := MburgS.nextCol;
      WHILE In(symSet[4], sym) DO
        Get;
      END;
      BurgAst.prodInfo[prod].semEnd := MburgS.pos + INT(MburgS.len);
    ELSIF In(symSet[5], sym) THEN
      BurgAst.prodInfo[prod].semPos := MburgS.nextPos;
              BurgAst.prodInfo[prod].semCol := MburgS.nextCol;
      Get;
      WHILE In(symSet[4], sym) DO
        Get;
      END;
      BurgAst.prodInfo[prod].semEnd := MburgS.pos + INT(MburgS.len);
    ELSIF (sym = pointrparenSym) THEN
    ELSE Error(31);
    END;
    Expect(pointrparenSym);
  END SemAction;

PROCEDURE  Cost (prod : BurgAst.ProdIndex);
  BEGIN
    IF (sym = numberSym) THEN
      Get;
      GetNumber(BurgAst.prodInfo[prod].prodCost);
    ELSIF (sym = pointSym) OR
          (sym = lparenpointSym) THEN
      BurgAst.prodInfo[prod].prodCost := 0;
    ELSE Error(32);
    END;
  END Cost;

PROCEDURE  PredFunc (prod : BurgAst.ProdIndex);
  VAR iPos : INTEGER;
  BEGIN
    IF (sym = andSym) THEN
      Get;
      iPos := MburgS.nextPos;
              BurgAst.prodInfo[prod].predBegin := iPos;
      IF (sym = identifierSym) THEN
        Get;
      END;
      BalancedPar;
      BurgAst.prodInfo[prod].predLength := MburgS.pos + 1 - iPos;
    ELSIF (sym = numberSym) OR
          (sym = pointSym) OR
          (sym = lparenpointSym) THEN
      BurgAst.prodInfo[prod].predBegin := 0;
    ELSE Error(33);
    END;
  END PredFunc;

PROCEDURE  Tree (VAR tree : BurgAst.Tree);
  VAR isaT : BOOLEAN;
       rPos : INTEGER;
       rLen : INTEGER;
       idnt : INTEGER;
  BEGIN
    Expect(identifierSym);
    rPos := MburgS.pos; rLen := MburgS.len;
    	                BurgAst.LookupT(rPos,rLen,idnt);
            IF idnt = 0 THEN
              isaT := FALSE;
              BurgAst.EnterNT(rPos,rLen,idnt);
              tree := BurgAst.NewNtTree(idnt);
            ELSE
              isaT := TRUE;
              tree := BurgAst.NewTmTree(idnt);
            END;
    IF (sym = lparenSym) THEN
      Get;
      IF NOT isaT THEN
         Error(51);
         BurgInOut.IdErrorMessage("terminal symbol",rPos,rLen,"is undeclared");
       END;
      Tree(tree^.left);
      IF (sym = commaSym) THEN
        Get;
        Tree(tree^.right);
        IF isaT THEN BurgAst.EnterArity(idnt,2) END;
      ELSIF (sym = rparenSym) THEN
        IF isaT THEN BurgAst.EnterArity(idnt,1) END;
      ELSE Error(34);
      END;
      Expect(rparenSym);
    ELSIF In(symSet[6], sym) THEN
      (* either: chain prod, or arity = 0 *);
      IF isaT THEN BurgAst.EnterArity(idnt,0) END;
    ELSE Error(35);
    END;
  END Tree;

PROCEDURE  NonTerm (VAR ntId : INTEGER);
  BEGIN
    Expect(identifierSym);
    BurgAst.EnterNT(MburgS.pos,MburgS.len,ntId);
  END NonTerm;

PROCEDURE  Rule;
  VAR ntId : INTEGER;
       iPos : INTEGER;
       prod : BurgAst.ProdIndex;
       tree : BurgAst.Tree;
  BEGIN
    iPos := MburgS.nextPos;
    NonTerm(ntId);
    Expect(equalSym);
    Tree(tree);
    BurgAst.EnterProd(iPos,ntId,tree,prod);
    PredFunc(prod);
    IF tree^.isChain THEN
       CardSequences.LinkRight(BurgAst.nonTermI[tree^.nonTerm].chainSeq,prod);
       IF BurgAst.prodInfo[prod].predBegin <> 0 THEN
         Error(50); BurgInOut.IdErrorMessage(
           "chain production of symbol",BurgAst.nonTermI[tree^.nonTerm].pos,
           BurgAst.nonTermI[tree^.nonTerm].len,"cannot be conditional");
       END;
     ELSE
       CardSequences.LinkRight(BurgAst.termInfo[tree^.terminal].prodList,prod);
       IF (BurgAst.prodInfo[prod].predBegin <> 0) AND
          (BurgAst.termInfo[tree^.terminal].termArity = 0) THEN
         Error(50); BurgInOut.IdErrorMessage(
           "leaf production of symbol",BurgAst.termInfo[tree^.terminal].pos,
           BurgAst.termInfo[tree^.terminal].len,"cannot be conditional");
       END;
     END;
    Cost(prod);
    IF (sym = lparenpointSym) THEN
      SemAction(prod);
    END;
    Expect(pointSym);
  END Rule;

PROCEDURE  Declaration;
  VAR ntId : INTEGER;
       tPos : INTEGER;
       tLen : INTEGER;
       numb : INTEGER;
  BEGIN
    CASE sym OF
      percentstartSym :
        Get;
        NonTerm(ntId);
        BurgAst.goalSmbl := ntId;
    | percentOPSym :
        Get;
        Expect(stringSym);
        BurgInOut.GetOpS;
    | percentNEWSym :
        Get;
        Expect(stringSym);
        BurgInOut.GetNewS;
    | percentENUMSym :
        Get;
        Expect(stringSym);
        BurgInOut.GetEnumS;
    | percentLEFTSym :
        Get;
        Expect(stringSym);
        BurgInOut.GetLeftS;
    | percentRIGHTSym :
        Get;
        Expect(stringSym);
        BurgInOut.GetRightS;
    | percentSTATESym :
        Get;
        Expect(stringSym);
        BurgInOut.GetStateS;
    | percentMNAMESym :
        Get;
        Expect(stringSym);
        BurgInOut.GetMnameS;
    | percentTNAMESym :
        Get;
        Expect(stringSym);
        BurgInOut.GetTnameS;
    | percentATTRSym :
        Get;
        Expect(lessSym);
        BurgAst.inclPos := MburgS.nextPos;
         BurgAst.inclCol := MburgS.nextCol;
        WHILE In(symSet[3], sym) DO
          Get;
        END;
        BurgAst.inclEnd := MburgS.pos + INT(MburgS.len);
        Expect(greaterSym);
    | percentFORMSym :
        Get;
        Expect(lessSym);
        BurgAst.formPos := MburgS.nextPos;
         BurgAst.formCol := MburgS.nextCol;
        WHILE In(symSet[3], sym) DO
          Get;
        END;
        BurgAst.formEnd := MburgS.pos + INT(MburgS.len);
        Expect(greaterSym);
    | percenttermSym :
        Get;
        WHILE (sym = identifierSym) DO
          Get;
          tPos := MburgS.pos;
                  tLen := MburgS.len;
          Expect(equalSym);
          Expect(numberSym);
          GetNumber(numb);
                  BurgAst.NewTerm(tPos,tLen,numb);
        END;
    ELSE Error(36);
    END;
  END Declaration;

PROCEDURE  Mburg;
  BEGIN
    Expect(HEADERSym);
    BurgInOut.hStart := MburgS.nextPos;
    WHILE In(symSet[7], sym) DO
      Get;
    END;
    BurgInOut.hEnd   := MburgS.nextPos;
    Expect(DECLARATIONSSym);
    WHILE In(symSet[8], sym) DO
      Declaration;
    END;
    Expect(RULESSym);
    WHILE (sym = identifierSym) DO
      Rule;
    END;
    Expect(ENDRULESSym);
  END Mburg;



PROCEDURE  Parse;
  BEGIN
    MburgS.Reset; Get;
    Mburg;

  END Parse;

BEGIN
  errDist := minErrDist;
  symSet[ 0, 0] := BITSET{EOFSYM};
  symSet[ 0, 1] := BITSET{};
  symSet[ 1, 0] := BITSET{identifierSym, numberSym, stringSym, HEADERSym, 
                    DECLARATIONSSym, RULESSym, ENDRULESSym, percentstartSym, 
                    percentOPSym, percentNEWSym, percentENUMSym, 
                    percentLEFTSym, percentRIGHTSym, percentSTATESym, 
                    percentMNAMESym};
  symSet[ 1, 1] := BITSET{percentTNAMESym-16, percentATTRSym-16, lessSym-16, 
                    greaterSym-16, percentFORMSym-16, percenttermSym-16, 
                    equalSym-16, pointSym-16, lparenpointSym-16, 
                    pointrparenSym-16, lparenSym-16, commaSym-16, andSym-16, 
                    NOSYM-16};
  symSet[ 2, 0] := BITSET{identifierSym, numberSym, stringSym, HEADERSym, 
                    DECLARATIONSSym, RULESSym, ENDRULESSym, percentstartSym, 
                    percentOPSym, percentNEWSym, percentENUMSym, 
                    percentLEFTSym, percentRIGHTSym, percentSTATESym, 
                    percentMNAMESym};
  symSet[ 2, 1] := BITSET{percentTNAMESym-16, percentATTRSym-16, lessSym-16, 
                    greaterSym-16, percentFORMSym-16, percenttermSym-16, 
                    equalSym-16, pointSym-16, lparenpointSym-16, 
                    pointrparenSym-16, commaSym-16, andSym-16, NOSYM-16};
  symSet[ 3, 0] := BITSET{identifierSym, numberSym, stringSym, HEADERSym, 
                    DECLARATIONSSym, RULESSym, ENDRULESSym, percentstartSym, 
                    percentOPSym, percentNEWSym, percentENUMSym, 
                    percentLEFTSym, percentRIGHTSym, percentSTATESym, 
                    percentMNAMESym};
  symSet[ 3, 1] := BITSET{percentTNAMESym-16, percentATTRSym-16, lessSym-16, 
                    percentFORMSym-16, percenttermSym-16, equalSym-16, 
                    pointSym-16, lparenpointSym-16, pointrparenSym-16, 
                    lparenSym-16, commaSym-16, rparenSym-16, andSym-16, 
                    NOSYM-16};
  symSet[ 4, 0] := BITSET{identifierSym, numberSym, stringSym, HEADERSym, 
                    DECLARATIONSSym, RULESSym, ENDRULESSym, percentstartSym, 
                    percentOPSym, percentNEWSym, percentENUMSym, 
                    percentLEFTSym, percentRIGHTSym, percentSTATESym, 
                    percentMNAMESym};
  symSet[ 4, 1] := BITSET{percentTNAMESym-16, percentATTRSym-16, lessSym-16, 
                    greaterSym-16, percentFORMSym-16, percenttermSym-16, 
                    equalSym-16, pointSym-16, lparenpointSym-16, lparenSym-16, 
                    commaSym-16, rparenSym-16, andSym-16, NOSYM-16};
  symSet[ 5, 0] := BITSET{identifierSym, numberSym, stringSym, HEADERSym, 
                    DECLARATIONSSym, RULESSym, ENDRULESSym, percentstartSym, 
                    percentOPSym, percentNEWSym, percentENUMSym, 
                    percentLEFTSym, percentRIGHTSym, percentSTATESym, 
                    percentMNAMESym};
  symSet[ 5, 1] := BITSET{percentTNAMESym-16, percentATTRSym-16, greaterSym-16, 
                    percentFORMSym-16, percenttermSym-16, equalSym-16, 
                    pointSym-16, lparenpointSym-16, lparenSym-16, commaSym-16, 
                    rparenSym-16, andSym-16, NOSYM-16};
  symSet[ 6, 0] := BITSET{numberSym};
  symSet[ 6, 1] := BITSET{pointSym-16, lparenpointSym-16, commaSym-16, rparenSym-16, 
                    andSym-16};
  symSet[ 7, 0] := BITSET{identifierSym, numberSym, stringSym, HEADERSym, RULESSym, 
                    ENDRULESSym, percentstartSym, percentOPSym, 
                    percentNEWSym, percentENUMSym, percentLEFTSym, 
                    percentRIGHTSym, percentSTATESym, percentMNAMESym};
  symSet[ 7, 1] := BITSET{percentTNAMESym-16, percentATTRSym-16, lessSym-16, 
                    greaterSym-16, percentFORMSym-16, percenttermSym-16, 
                    equalSym-16, pointSym-16, lparenpointSym-16, 
                    pointrparenSym-16, lparenSym-16, commaSym-16, rparenSym-16, 
                    andSym-16, NOSYM-16};
  symSet[ 8, 0] := BITSET{percentstartSym, percentOPSym, percentNEWSym, 
                    percentENUMSym, percentLEFTSym, percentRIGHTSym, 
                    percentSTATESym, percentMNAMESym};
  symSet[ 8, 1] := BITSET{percentTNAMESym-16, percentATTRSym-16, percentFORMSym-16, 
                    percenttermSym-16};
END MburgP.

