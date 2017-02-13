defmodule Accounting.XeroView do
  def render("start_link.xml") do
    """
    <TrackingCategories>
      <TrackingCategory>
        <Name>Category</Name>
      </TrackingCategory>
    </TrackingCategories>
    """
  end

  def render("register_categories.xml", assigns) do
    """
    <Options>
      #{for category <- assigns[:categories] do
          render("category.xml", category: category)
        end}
    </Options>
    """
  end
  def render("category.xml", assigns) do
    """
    <Option>
      <Name>#{xml_escape to_string(assigns[:category])}</Name>
    </Option>
    """
  end
  def render("receive_money.xml", assigns) do
    """
    <BankTransactions>
      <BankTransaction>
        <Type>RECEIVE</Type>
        <Contact><Name>#{xml_escape assigns[:from]}</Name></Contact>
        <Date>#{assigns[:date]}</Date>
        <LineItems>
          #{for line_item <- assigns[:line_items] do
              render("line_item.xml", line_item: line_item)
            end}
        </LineItems>
        <BankAccount>
          <AccountID>
            #{Application.get_env(:accounting, :bank_account_id)}
          </AccountID>
        </BankAccount>
      </BankTransaction>
    </BankTransactions>
    """
  end
  def render("spend_money.xml", assigns) do
    """
    <BankTransactions>
      <BankTransaction>
        <Type>SPEND</Type>
        <Contact><Name>#{xml_escape assigns[:to]}</Name></Contact>
        <Date>#{assigns[:date]}</Date>
        <LineItems>
          #{for line_item <- assigns[:line_items] do
              render("line_item.xml", line_item: line_item)
            end}
        </LineItems>
        <BankAccount>
          <AccountID>
            #{Application.get_env(:accounting, :bank_account_id)}
          </AccountID>
        </BankAccount>
      </BankTransaction>
    </BankTransactions>
    """
  end
  def render("transfer.xml", assigns) do
    """
    <Invoices>
      <Invoice>
        <Type>ACCREC</Type>
        <Status>AUTHORISED</Status>
        <Contact><Name>#{xml_escape assigns[:from]}</Name></Contact>
        <Date>#{assigns[:date]}</Date>
        <DueDate>#{assigns[:date]}</DueDate>
        <LineAmountTypes>NoTax</LineAmountTypes>
        <LineItems>
          #{for line_item <- assigns[:line_items] do
              render("line_item.xml", line_item: line_item)
            end}
        </LineItems>
      </Invoice>
    </Invoices>
    """
  end
  def render("line_item.xml", assigns) do
    """
    <LineItem>
      <Description>
        #{xml_escape assigns[:line_item].description}
      </Description>
      <Quantity>1</Quantity>
      <UnitAmount>
        #{dollar_string_from_pennies assigns[:line_item].amount}
      </UnitAmount>
      <AccountCode>
        #{xml_escape assigns[:line_item].account_number}
      </AccountCode>
      <Tracking>
        <TrackingCategory>
          <Name>Category</Name>
          <Option>
            #{xml_escape to_string(assigns[:line_item].category)}
          </Option>
        </TrackingCategory>
      </Tracking>
    </LineItem>
    """
  end
  def render("create_account.xml", assigns) do
    """
    <Account>
      <Code>#{xml_escape assigns[:number]}</Code>
      <Name>#{xml_escape assigns[:number]}</Name>
      <Type>CURRLIAB</Type>
    </Account>
    """
  end

  defp dollar_string_from_pennies(pennies) when is_integer(pennies) do
    pennies
    |> Kernel./(100.0)
    |> :erlang.float_to_binary([{:decimals, 2}, :compact])
  end

  defp xml_escape(string) when is_binary(string) do
    IO.iodata_to_binary(for <<char <- string>>, do: escape_char(char))
  end

  defp escape_char(?"), do: "&quot;"
  defp escape_char(?'), do: "&#39;"
  defp escape_char(?<), do: "&lt;"
  defp escape_char(?>), do: "&gt;"
  defp escape_char(?&), do: "&amp;"
  defp escape_char(char), do: char
end
