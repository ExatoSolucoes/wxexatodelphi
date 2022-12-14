program WebservicesExato;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.IOUtils,
  Generics.Collections,
  ClassWSExato in 'ClassWSExato.pas';

type
  TValReq = TDictionary<string,string>;

var
  ws : WSExato;
  resp : WSResposta;
  log : ClassWSExato.TStringArr;
  servico, k, arquivo, URLWS, USWS, CHWS, CLCONC : string;
  i : integer;
  vars : TValReq;

begin

  // informa??es de acesso ao servi?o (fornecidas pela Exato Solu??es)
  URLWS := 'endere?o do webservice';
  USWS := 'usu?rio de acesso';
  CHWS := 'chave de 32 caracteres';
  CLCONC := 'identificador do cliente';

  // criando o acesso aos webservices
  ws := WSExato.Create(URLWS, USWS);
  vars := TValReq.Create;

  // indique o servi?o a ser chamado
  servico := 'concilia??o erp'; // conciliar informa??es com o sistema de vendas
  //servico := 'extrato de movimenta??o'; // recuperar extrato de movimenta??o
  //servico := 'concilia??o banc?ria'; // conciliar informa??es de extrato banc?rio
  //servico := 'extrato banc?rio'; // envio de extrato banc?rio
  //servico := 'quita??o'; // confer?ncias de parcelas quitadas

  // conciliar informa??es com o sistema de vendas
  if (servico = 'concilia??o erp') then begin

    // carregando o texto do arquivo de extrato
    arquivo := TFile.ReadAllText('exemploerp.json');

    // vari?veis da requisi??o
    vars.Add('c', CLCONC); // o identificador do cliente, fornecido pela Exato Solu??es
    vars.Add('req', arquivo); // o texto de requisi??o
    vars.Add('t', 'venda'); // o tipo de requisi??o ("venda" ou "pagamento")

    // texto da chave (usu?rio + cliente + tip? de requisi??o + texto da requisi??o)
    k := USWS + CLCONC + 'venda' + arquivo;

    // chamando o servi?o
    resp := ws.requisitar('vdk-cartoes/conciliacao-erp', CHWS, k, vars);

  end;

  // recuperar extrato de movimenta??o
  if (servico = 'extrato de movimenta??o') then begin

    // vari?veis da requisi??o
    vars.Add('id', CLCONC); // o identificador do cliente, fornecido pela Exato Solu??es
    vars.Add('dini', '01/03/2022'); // data inicial do per?odo
    vars.Add('dfim', '05/03/2022'); // data final do per?odo
    vars.Add('tp', 'venda'); // o tipo de movimenta??o ("venda" ou "pagamento")
    vars.Add('l', 'exato.json'); // formato da lista a receber

    // texto da chave (cliente + data inicial + data final + tipo de movimenta??o)
    k := CLCONC + '01/03/2022' + '05/03/2022' + 'venda';

    // chamando o servi?o
    resp := ws.requisitar('vdk-cartoes/extrato-recuperacao', CHWS, k, vars);

  end;

  // conciliar informa??es de extrato banc?rio
  if (servico = 'concilia??o banc?ria') then begin

    // carregando o texto do arquivo de extrato
    arquivo := TFile.ReadAllText('caminho para o arquivo cnab ou ofx');

    // vari?veis da requisi??o
    vars.Add('c', CLCONC); // o identificador do cliente, fornecido pela Exato Solu??es
    vars.Add('e', arquivo); // o texto do extrato (OFX ou CNAB)
    vars.Add('b', 'conta banc?ria'); // conta banc?ria no formato banco-ag?ncia-conta
    vars.Add('q', 'sim'); // receber informa??es de quita??o nda resposta? (sim/n?o)

    // texto da chave (usu?rio + cliente + conta banc?ria + texto do extrato)
    k := USWS + CLCONC + 'conta banc?ria' + arquivo;

    // chamando o servi?o
    resp := ws.requisitar('vdk-cartoes/bancario', CHWS, k, vars);

  end;

  // enviando extrato banc?rio para processamento
  if (servico = 'extrato banc?rio') then begin

    // carregando o texto do arquivo de extrato
    arquivo := TFile.ReadAllText('caminho para o arquivo cnab ou ofx');

    // vari?veis da requisi??o
    vars.Add('c', CLCONC); // o identificador do cliente, fornecido pela Exato Solu??es
    vars.Add('e', arquivo); // o texto do extrato (OFX ou CNAB)
    vars.Add('b', 'conta banc?ria'); // conta banc?ria no formato banco-ag?ncia-conta
    vars.Add('m', 'n?o'); // o extrato ? um CNAB multi conta? (sim/n?o)

    // texto da chave (usu?rio + cliente + texto do extrato)
    k := USWS + CLCONC + arquivo;

    // chamando o servi?o
    resp := ws.requisitar('vdk-cartoes/extrato-bancario', CHWS, k, vars);

  end;

  // conferindo a quita??o de parcelas
  if (servico = 'quita??o') then begin

    // vari?veis da requisi??o
    vars.Add('c', CLCONC); // o identificador do cliente, fornecido pela Exato Solu??es
    vars.Add('d', '05/07/2022'); // data a consultar no formato DD/MM/AAAA ou AAAA-MM-DD
    vars.Add('cn', '00000000000000'); // CNPJ da loja (n?o enviar ou deixar em branco para todas as do cliente)

    // texto da chave (usu?rio + cliente + data)
    k := USWS + CLCONC + '05/07/2022';

    // chamando o servi?o
    resp := ws.requisitar('vdk-cartoes/quitacao', CHWS, k, vars);

  end;

  // finalizando
  WriteLn('Chamada ao servi?o finalizada com o erro ' + IntToStr(resp.e) + ' (' + resp.msg +').');

  // registrando o resultado do chamado
  TFile.WriteAllText('resposta.json', resp.original);
  WriteLn('O arquivo resposta.json, trazendo a resposta do chamado, foi gravado.');

  // exibindo o log da opera??o
  WriteLn('');
  WriteLn('LOG DA REQUISI??O');
  log := ws.recLog;
  for i := 0 to (Length(log)-1) do WriteLn(log[i]);

  // interrompendo a execu??o
  ReadLn;

end.
