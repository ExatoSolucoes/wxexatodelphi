unit ClassWSExato;

interface

  uses
    System.SysUtils, System.JSON, StrUtils, Generics.Collections, IdHashMessageDigest, idHttp, System.Classes, IdURI;

  type
    // lista de strings para logs
    TStringArr = array of string;

    // valores de requisi??o
    TValReq = TDictionary<string,string>;

    // resposta do acesso a webservices Exato Solu??es
    WSResposta = class

      PUBLIC

        e : integer;          // erro da requisi??o
        msg : string;         // descri??o do erro da requisi??o
        r : string;           // rota requsitada
        h : string;           // data/hora da resposta
        evt : TStringArr;     // eventos da resposta
        original : string;    // texto original da resposta

        (*
         * Construtor da classe.
         *)
        Constructor Create;

        (*
         * Recebe e processa um texto de resposta de requisi??o.
         * resp => o texto da resposta
         * retorna true se a resposta foi processada corretamente, false ao contr?rio
         *)
        function recebe(resp : string) : boolean;

        (*
         * Define a mensagem de acordo com o c?digo de erro.
         *)
        procedure defineMsg;

    end;

    // accesso a webservices Exato Solu??es (exatosolucoes.com.br)
    WSExato = class

      PRIVATE

        url : string;       // endere?o de acesso aos webservices
        usuario : string;   // identificador do usu?rio do webservice
        log : TStringArr;   // log de requisi??o

        (*
         * Adiciona uma entrada ao log de execu??o.
         * tx => o texto a adicionar
         *)
        procedure adLog(tx : string);

      PUBLIC

        (*
         * Construtor da classe.
         * ur => url de acesso aos webservices
         * us => usu?rio de acesso aos servi?os
         *)
        Constructor Create(ur : string; us : string);

        (*
         * Recupera o log atual de processamento.
         * retorna um objeto ClassWSExato.TStringArr contendo linhas do log
         *)
        function recLog : TStringArr;

        (*
         * Faz uma chamada a um webservice.
         * rota => a rota do servi?o
         * chave => a chave de 32 caracteres do usu?rio
         * k => o texto a ser usado na forma??o da vari?vel "k" (sem a chave)
         * vars => vari?veis usadas na requisi??o ("r", "u" e "k" s?o adicionadas automaticamente)
         * retorna a resposta, incluindo o c?digo de erro "e" e uma mensagem explicativa "msg"
         *)
        function requisitar(rota : string; chave : string; k : string; vars : TValReq) : WSResposta;
        
    end;


implementation

  { WSExato }

  Constructor WSExato.Create(ur: string; us : string);
  begin
    url := ur;
    usuario := us;
    SetLength(log, 0);
  end;

  function WSExato.recLog : TStringArr;
  begin
    Result := log;
  end;

  function WSExato.requisitar(rota : string; chave : string; k : string; vars : TValReq) : WSResposta;
  var
    resp : WSResposta;
    idmd5 : TIdHashMessageDigest5;
    http : TIdHTTP;
    res : string;
    postVars : TStringList;
    item : TPair<string, string>;
    recok : boolean;
  begin
    // preparando a resposta
    resp := WSResposta.Create;

    // iniciando o log
    SetLength(log, 0);
    adLog('in?cio da requisi??o');

    // validando a rota
    if (ContainsText(rota, '/')) then
      begin
        // seguindo a requisi??o
        adLog('rota definida como ' + rota);

        // criando a chave
        idmd5 := TIdHashMessageDigest5.Create;
        try
          k := LowerCase(idmd5.HashStringAsHex(chave + k));
          adLog('chave de acesso definida como ' + k);
        finally
          idmd5.Free;
        end;

        // repassando valores
        vars.Remove('u');
        vars.Remove('k');
        vars.Remove('r');
        vars.Remove('fr');
        vars.Add('r', rota);
        vars.Add('u', usuario);
        vars.Add('k', k);
        vars.Add('fr', 'txt');
        postVars := TStringList.Create;
        //for item in vars do postVars.Add(item.Key + '=' + TIdURI.ParamsEncode(item.Value));
        for item in vars do postVars.Add(item.Key + '=' + item.Value);

        // fazendo a requisi??o
        http := TIdHTTP.Create;
        res := '';
        try
          adLog('acessando ' + url);
          res := http.Post(url, postVars);
          recok := True;
        except
          recok := False;
        end;

        if recok then
          begin
            // liberando objetos
            http.Free;
            postVars.Free;
            // recebendo valores
            resp.recebe(res);
          end
        else
          begin
            adLog('erro ao acessar o webservice');
            resp.e := -11;
          end;
      end
    else
      begin
        // rota inv?lida
        adLog('a rota indicada (' + rota  + ') ? inv?lida');
        resp.e := -10;
      end;
      
    // identificando a mensagem de erro
    resp.defineMsg;

    // retornando
    adLog('erro (' + IntToStr(resp.e) + '): ' + resp.msg);
    adLog('acesso finalizado');
    Result := resp;
  end;

  procedure WSExato.adLog(tx : string);
  begin
    SetLength(log, (Length(log)+1));
    log[Length(log)-1] := FormatDateTime('dd/MM/yyyy hh:mm:ss', Now) + ' => ' + tx;
  end;

  { WSResposta }

  Constructor WSResposta.Create;
  begin
    e := 0;
    r := '';
    h := '';
    SetLength(evt, 0);
  end;

  function WSResposta.recebe(resp : string) : boolean;
  var
    jsonO : TJSonObject;
    json : TJSonValue;
    st : string;
    ok : boolean;
    evta : TJSONArray;
    i : integer;
  begin
    // texto original
    original := resp;
    // recebendo JSON
    SetLength(evt, 0);
    jsonO := TJSonObject.Create;
    json := jsonO.ParseJSONValue(resp);
    if json is TJSONObject then
      begin
        // json v?lido
        if ((json as TJSONObject).Get('e') <> nil) then
          begin
            // resposta ok (vari?vel e encontrada)
            ok := True;
            e := StrToInt((json as TJSONObject).Get('e').JsonValue.Value);
            if ((json as TJSONObject).Get('r') <> nil) then  r := (json as TJSONObject).Get('r').JsonValue.Value;
            if ((json as TJSONObject).Get('h') <> nil) then  h := (json as TJSONObject).Get('h').JsonValue.Value;
            if ((json as TJSONObject).Get('evt') <> nil) then
              begin
                // recuperando cada evento recebido
                if ((json as TJSONObject).Get('evt').JsonValue is TJSONArray) then
                  begin
                    evta := (json as TJSONObject).Get('evt').JsonValue as TJSONArray;
                    SetLength(evt, evta.Count);
                    for i := 0 to (evta.Count - 1) do
                      begin
                        evt[i] := evta.Items[i].Value;
                      end;
                  end;
              end;
          end
        else 
          begin
            // falta vari?vel e
            ok := False;
            e := -13;
          end;
        json.Free;
      end
    else 
      begin
        // json corrompido
        ok := False;
        e := -12;
      end;
    Result := ok;
  end;

  procedure WSResposta.defineMsg;
  begin
    msg := 'erro espec?fico do servi?o requisitado, consulte o material de refer?ncia';
    case e of
      0 : msg := 'requisi??o finalizada com sucesso';
      -1 : msg := 'rota de webservice n?o indicada';  
      -2 : msg := 'rota de webservice inv?lida';
      -3 : msg := 'rota de webservice n?o localizada';
      -4 : msg := 'chave de valida??o incorreta ou falta de vari?vel essencial';
      -10 : msg := 'rota inv?lida';
      -11 : msg := 'erro no acesso ao webservice';
      -12 : msg := 'resposta do webservice corrompida';
      -13 : msg := 'resposta do webservice corrompida (falta e)';
    end;
  end;

end.
