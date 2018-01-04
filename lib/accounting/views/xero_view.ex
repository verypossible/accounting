defmodule Accounting.XeroView do
  @moduledoc false

  alias Accounting.{Entry, LineItem}

  @spec render(String.t) :: String.t
  def render("start_link.xml") do
    """
    <TrackingCategories>
      <TrackingCategory>
        <Name>Category</Name>
      </TrackingCategory>
    </TrackingCategories>
    """
  end

  @spec render(String.t, keyword) :: String.t
  def render("bank_transactions.xml", assigns) do
    """
    <BankTransactions>
      #{
        for entry <- assigns[:entries] do
          render_bank_transaction(entry, assigns[:bank_account_id])
        end
      }
    </BankTransactions>
    """
  end
  def render("invoices.xml", assigns) do
    """
    <Invoices>
      #{for entry <- assigns[:entries], do: render_invoice(entry)}
    </Invoices>
    """
  end
  def render("register_account.xml", assigns) do
    """
    <Account>
      <Code>#{xml_escape assigns[:number]}</Code>
      <Name>#{xml_escape assigns[:name]}</Name>
      <Type>CURRLIAB</Type>
    </Account>
    """
  end
  def render("register_categories.xml", assigns) do
    """
    <Options>
      #{for category <- assigns[:categories], do: render_category(category)}
    </Options>
    """
  end
  def render("setup_accounts.xml", assigns) do
    """
    <Setup>
      <Accounts>
        #{for a <- assigns[:accounts], do: render("register_account.xml", a)}
      </Accounts>
    </Setup>
    """
  end
  def render("setup_account_conversions.xml", assigns) do
    """
    <Setup>
      <ConversionDate>
        <Month>#{assigns[:month]}</Month>
        <Year>#{assigns[:year]}</Year>
      </ConversionDate>
      <ConversionBalances>
        #{for a <- assigns[:accounts], do: render_conversion_accounts(a)}
      </ConversionBalances>
    </Setup>
    """
  end

  @spec render_conversion_accounts(keyword) :: String.t
  defp render_conversion_accounts(account) do
    """
    <ConversionBalance>
      <AccountCode>#{xml_escape account[:number]}</AccountCode>
      <Balance>#{xml_escape account[:conversion_balance]}</Balance>
    </ConversionBalance>
    """
  end

  @spec bank_transaction_type(integer) :: String.t
  defp bank_transaction_type(total) when total < 0, do: "SPEND"
  defp bank_transaction_type(total) when total > 0, do: "RECEIVE"

  @spec render_reverse_line_item(LineItem.t) :: String.t
  defp render_reverse_line_item(line_item) do
    render_line_item(%{line_item|amount: -line_item.amount})
  end

  @spec render_line_item(LineItem.t) :: String.t
  defp render_line_item(line_item) do
    """
    <LineItem>
      <Description>
        #{xml_escape line_item.description}
      </Description>
      <Quantity>1</Quantity>
      <UnitAmount>
        #{dollar_string_from_pennies line_item.amount}
      </UnitAmount>
      <AccountCode>
        #{xml_escape line_item.account_number}
      </AccountCode>
      <Tracking>
        <TrackingCategory>
          <Name>Category</Name>
          <Option>
            #{xml_escape to_string(line_item.category)}
          </Option>
        </TrackingCategory>
      </Tracking>
    </LineItem>
    """
  end

  @spec line_item_renderer(Entry.t) :: (LineItem.t -> String.t)
  defp line_item_renderer(entry) do
    cond do
      entry.total >= 0 -> &render_line_item/1
      entry.total < 0 -> &render_reverse_line_item/1
    end
  end

  @spec render_category(atom) :: String.t
  defp render_category(category) do
    """
    <Option>
      <Name>#{xml_escape to_string(category)}</Name>
    </Option>
    """
  end

  @spec render_bank_transaction(Entry.t, String.t) :: String.t
  defp render_bank_transaction(entry, bank_account_id) do
    render_item_fun = line_item_renderer(entry)

    """
    <BankTransaction>
      <Type>#{bank_transaction_type(entry.total)}</Type>
      <Contact><Name>#{xml_escape entry.party}</Name></Contact>
      <Date>#{entry.date}</Date>
      <LineItems>
        #{for line_item <- entry.line_items, do: render_item_fun.(line_item)}
      </LineItems>
      <BankAccount>
        <AccountID>#{xml_escape bank_account_id}</AccountID>
      </BankAccount>
    </BankTransaction>
    """
  end

  @spec render_invoice(Entry.t) :: String.t
  defp render_invoice(entry) do
    render_item_fun = line_item_renderer(entry)

    """
    <Invoice>
      <Type>#{invoice_type entry}</Type>
      <Status>AUTHORISED</Status>
      <Contact><Name>#{xml_escape entry.party}</Name></Contact>
      <Date>#{entry.date}</Date>
      <DueDate>#{entry.date}</DueDate>
      <LineAmountTypes>NoTax</LineAmountTypes>
      <LineItems>
        #{for line_item <- entry.line_items, do: render_item_fun.(line_item)}
      </LineItems>
    </Invoice>
    """
  end

  defp invoice_type(entry) do
    if entry.total >= 0 do
      "ACCREC"
    else
      "ACCPAY"
    end
  end

  @spec dollar_string_from_pennies(integer) :: String.t
  defp dollar_string_from_pennies(pennies) when is_integer(pennies) do
    pennies
    |> Kernel./(100.0)
    |> :erlang.float_to_binary([{:decimals, 2}, :compact])
  end

  @spec xml_escape(String.t) :: String.t
  defp xml_escape(string) when is_binary(string) do
    IO.iodata_to_binary(for <<char <- string>>, do: escape_char(char))
  end

  @spec escape_char(byte) :: String.t | char
  defp escape_char(?"), do: "&quot;"
  defp escape_char(?'), do: "&#39;"
  defp escape_char(?<), do: "&lt;"
  defp escape_char(?>), do: "&gt;"
  defp escape_char(?&), do: "&amp;"
  defp escape_char(char), do: char
end
