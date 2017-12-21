defmodule Accounting.XeroViewTest do
  use ExUnit.Case, async: true
  doctest Accounting.Entry

  alias Accounting.{Entry, LineItem, XeroView}

  test "render setup_accounts.xml" do
    assigns = [
      accounts: [
        [number: "1", name: "Moe"],
        [number: "2", name: "Curly"],
      ],
    ]

    xml = """
    <Setup>
      <Accounts>
        <Account>
          <Code>1</Code>
          <Name>Moe</Name>
          <Type>CURRLIAB</Type>
        </Account>
        <Account>
          <Code>2</Code>
          <Name>Curly</Name>
          <Type>CURRLIAB</Type>
        </Account>
      </Accounts>
    </Setup>
    """

    result = XeroView.render("setup_accounts.xml", assigns)
    assert remove_whitespace(xml) === remove_whitespace(result)
  end

  test "render setup_account_conversions.xml" do
    assigns = [
      month: 1,
      year: 2014,
      accounts: [
        [number: "1", conversion_balance: "5.00"],
        [number: "2", conversion_balance: "-2.00"],
      ],
    ]

    xml = """
    <Setup>
      <ConversionDate>
        <Month>1</Month>
        <Year>2014</Year>
      </ConversionDate>
      <ConversionBalances>
        <ConversionBalance>
          <AccountCode>1</AccountCode>
          <Balance>5.00</Balance>
        </ConversionBalance>
        <ConversionBalance>
          <AccountCode>2</AccountCode>
          <Balance>-2.00</Balance>
        </ConversionBalance>
      </ConversionBalances>
    </Setup>
    """

    result = XeroView.render("setup_account_conversions.xml", assigns)
    assert remove_whitespace(xml) === remove_whitespace(result)
  end

  test "render bank_transactions.xml with a single net-positive entry" do
    line_items = [
      %LineItem{account_number: "num", amount: 1, description: "boom"},
      %LineItem{account_number: "num", amount: 2, description: "town"},
    ]
    entry = Entry.new("Bob", ~D[2012-02-01], line_items)
    assigns = [bank_account_id: "1234", entries: [entry]]

    xml = """
    <BankTransactions>
      <BankTransaction>
        <Type>RECEIVE</Type>
        <Contact><Name>#{entry.party}</Name></Contact>
        <Date>#{entry.date}</Date>
        <LineItems>
          <LineItem>
            <Description>boom</Description>
            <Quantity>1</Quantity>
            <UnitAmount>0.01</UnitAmount>
            <AccountCode>num</AccountCode>
            <Tracking>
              <TrackingCategory>
                <Name>Category</Name>
                <Option>other</Option>
              </TrackingCategory>
            </Tracking>
          </LineItem>
          <LineItem>
            <Description>town</Description>
            <Quantity>1</Quantity>
            <UnitAmount>0.02</UnitAmount>
            <AccountCode>num</AccountCode>
            <Tracking>
              <TrackingCategory>
                <Name>Category</Name>
                <Option>other</Option>
              </TrackingCategory>
            </Tracking>
          </LineItem>
        </LineItems>
        <BankAccount>
          <AccountID>#{assigns[:bank_account_id]}</AccountID>
        </BankAccount>
      </BankTransaction>
    </BankTransactions>
    """

    assert remove_whitespace(xml) ===
      remove_whitespace(XeroView.render("bank_transactions.xml", assigns))
  end

  test "render bank_transactions.xml with a single net-negative entry" do
    line_items = [
      %LineItem{account_number: "num", amount: 1, description: "boom"},
      %LineItem{account_number: "num", amount: -2, description: "town"},
    ]
    entry = Entry.new("Bob", ~D[2012-02-01], line_items)
    assigns = [bank_account_id: "1234", entries: [entry]]

    xml = """
    <BankTransactions>
      <BankTransaction>
        <Type>SPEND</Type>
        <Contact><Name>#{entry.party}</Name></Contact>
        <Date>#{entry.date}</Date>
        <LineItems>
          <LineItem>
            <Description>boom</Description>
            <Quantity>1</Quantity>
            <UnitAmount>-0.01</UnitAmount>
            <AccountCode>num</AccountCode>
            <Tracking>
              <TrackingCategory>
                <Name>Category</Name>
                <Option>other</Option>
              </TrackingCategory>
            </Tracking>
          </LineItem>
          <LineItem>
            <Description>town</Description>
            <Quantity>1</Quantity>
            <UnitAmount>0.02</UnitAmount>
            <AccountCode>num</AccountCode>
            <Tracking>
              <TrackingCategory>
                <Name>Category</Name>
                <Option>other</Option>
              </TrackingCategory>
            </Tracking>
          </LineItem>
        </LineItems>
        <BankAccount>
          <AccountID>#{assigns[:bank_account_id]}</AccountID>
        </BankAccount>
      </BankTransaction>
    </BankTransactions>
    """

    assert remove_whitespace(xml) ===
      remove_whitespace(XeroView.render("bank_transactions.xml", assigns))
  end

  test "render bank_transactions.xml with multiple entries" do
    item1 = %LineItem{account_number: "T1", amount: -500_00, description: "Web"}
    entry1 = Entry.new("Blue Fairy", ~D[1401-03-27], [item1])
    item2 = %LineItem{account_number: "V28", amount: 4_17, description: "Gum"}
    entry2 = Entry.new("Jimminy Cricket", ~D[1703-04-19], [item2])
    assigns = [bank_account_id: "1234", entries: [entry1, entry2]]
    xml = """
    <BankTransactions>
      <BankTransaction>
        <Type>SPEND</Type>
        <Contact><Name>#{entry1.party}</Name></Contact>
        <Date>#{entry1.date}</Date>
        <LineItems>
          <LineItem>
            <Description>#{item1.description}</Description>
            <Quantity>1</Quantity>
            <UnitAmount>500.0</UnitAmount>
            <AccountCode>#{item1.account_number}</AccountCode>
            <Tracking>
              <TrackingCategory>
                <Name>Category</Name>
                <Option>other</Option>
              </TrackingCategory>
            </Tracking>
          </LineItem>
        </LineItems>
        <BankAccount>
          <AccountID>#{assigns[:bank_account_id]}</AccountID>
        </BankAccount>
      </BankTransaction>
      <BankTransaction>
        <Type>RECEIVE</Type>
        <Contact><Name>#{entry2.party}</Name></Contact>
        <Date>#{entry2.date}</Date>
        <LineItems>
          <LineItem>
            <Description>#{item2.description}</Description>
            <Quantity>1</Quantity>
            <UnitAmount>4.17</UnitAmount>
            <AccountCode>#{item2.account_number}</AccountCode>
            <Tracking>
              <TrackingCategory>
                <Name>Category</Name>
                <Option>other</Option>
              </TrackingCategory>
            </Tracking>
          </LineItem>
        </LineItems>
        <BankAccount>
          <AccountID>#{assigns[:bank_account_id]}</AccountID>
        </BankAccount>
      </BankTransaction>
    </BankTransactions>
    """

    assert remove_whitespace(xml) ===
      remove_whitespace(XeroView.render("bank_transactions.xml", assigns))
  end

  test "render invoices.xml with a single entry" do
    item1 = %LineItem{account_number: "G123", amount: 3, description: "toon"}
    item2 = %LineItem{account_number: "F456", amount: -3, description: "ton"}
    entry = Entry.new("Bill", ~D[2013-02-01], [item1, item2])
    assigns = [entries: [entry]]
    xml = """
    <Invoices>
      <Invoice>
        <Type>ACCREC</Type>
        <Status>AUTHORISED</Status>
        <Contact><Name>#{entry.party}</Name></Contact>
        <Date>#{entry.date}</Date>
        <DueDate>#{entry.date}</DueDate>
        <LineAmountTypes>NoTax</LineAmountTypes>
        <LineItems>
          <LineItem>
            <Description>#{item1.description}</Description>
            <Quantity>1</Quantity>
            <UnitAmount>0.03</UnitAmount>
            <AccountCode>#{item1.account_number}</AccountCode>
            <Tracking>
              <TrackingCategory>
                <Name>Category</Name>
                <Option>other</Option>
              </TrackingCategory>
            </Tracking>
          </LineItem>
          <LineItem>
            <Description>#{item2.description}</Description>
            <Quantity>1</Quantity>
            <UnitAmount>-0.03</UnitAmount>
            <AccountCode>#{item2.account_number}</AccountCode>
            <Tracking>
              <TrackingCategory>
                <Name>Category</Name>
                <Option>other</Option>
              </TrackingCategory>
            </Tracking>
          </LineItem>
        </LineItems>
      </Invoice>
    </Invoices>
    """

    assert remove_whitespace(xml) ===
      remove_whitespace(XeroView.render("invoices.xml", assigns))
  end

  test "render invoices.xml with multiple entries" do
    item1a = %LineItem{account_number: "Y21", amount: 13, description: "Hair"}
    item1b = %LineItem{account_number: "W19", amount: -13, description: "Wig"}
    entry1 = Entry.new("Bill", ~D[2013-02-01], [item1a, item1b])
    item2a = %LineItem{account_number: "R90", amount: 5, description: "Yams"}
    item2b = %LineItem{account_number: "A70", amount: -5, description: "Tubers"}
    entry2 = Entry.new("June", ~D[1862-10-19], [item2a, item2b])
    assigns = [entries: [entry1, entry2]]
    xml = """
    <Invoices>
      <Invoice>
        <Type>ACCREC</Type>
        <Status>AUTHORISED</Status>
        <Contact><Name>#{entry1.party}</Name></Contact>
        <Date>#{entry1.date}</Date>
        <DueDate>#{entry1.date}</DueDate>
        <LineAmountTypes>NoTax</LineAmountTypes>
        <LineItems>
          <LineItem>
            <Description>#{item1a.description}</Description>
            <Quantity>1</Quantity>
            <UnitAmount>0.13</UnitAmount>
            <AccountCode>#{item1a.account_number}</AccountCode>
            <Tracking>
              <TrackingCategory>
                <Name>Category</Name>
                <Option>other</Option>
              </TrackingCategory>
            </Tracking>
          </LineItem>
          <LineItem>
            <Description>#{item1b.description}</Description>
            <Quantity>1</Quantity>
            <UnitAmount>-0.13</UnitAmount>
            <AccountCode>#{item1b.account_number}</AccountCode>
            <Tracking>
              <TrackingCategory>
                <Name>Category</Name>
                <Option>other</Option>
              </TrackingCategory>
            </Tracking>
          </LineItem>
        </LineItems>
      </Invoice>
      <Invoice>
        <Type>ACCREC</Type>
        <Status>AUTHORISED</Status>
        <Contact><Name>#{entry2.party}</Name></Contact>
        <Date>#{entry2.date}</Date>
        <DueDate>#{entry2.date}</DueDate>
        <LineAmountTypes>NoTax</LineAmountTypes>
        <LineItems>
          <LineItem>
            <Description>#{item2a.description}</Description>
            <Quantity>1</Quantity>
            <UnitAmount>0.05</UnitAmount>
            <AccountCode>#{item2a.account_number}</AccountCode>
            <Tracking>
              <TrackingCategory>
                <Name>Category</Name>
                <Option>other</Option>
              </TrackingCategory>
            </Tracking>
          </LineItem>
          <LineItem>
            <Description>#{item2b.description}</Description>
            <Quantity>1</Quantity>
            <UnitAmount>-0.05</UnitAmount>
            <AccountCode>#{item2b.account_number}</AccountCode>
            <Tracking>
              <TrackingCategory>
                <Name>Category</Name>
                <Option>other</Option>
              </TrackingCategory>
            </Tracking>
          </LineItem>
        </LineItems>
      </Invoice>
    </Invoices>
    """

    assert remove_whitespace(xml) ===
      remove_whitespace(XeroView.render("invoices.xml", assigns))
  end

  defp remove_whitespace(string) do
    string
    |> String.replace(~r/>\s+</, "><")
    |> String.replace(~r/>\s+/, ">")
    |> String.replace(~r/\s+</, "<")
  end
end
