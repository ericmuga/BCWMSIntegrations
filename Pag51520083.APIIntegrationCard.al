page 51520083 "Integration Setup Card"
{
    PageType = Card;
    ApplicationArea = All;
    SourceTable = "Integration Setup";
    UsageCategory = Administration;
    Caption = 'API Configuration';
    Editable = true;

    layout
    {
        area(content)
        {
            group("General")
            {
                field(Code; Rec.Code)
                {
                    ApplicationArea = All;
                    Editable = true;
                }
                field(APIBaseUrl; Rec.APIBaseUrl)
                {
                    ApplicationArea = All;
                    Editable = true;
                }
                field(EndpointUrl; Rec.EndpointUrl)
                {
                    ApplicationArea = All;
                    Editable = true;
                }
                field(MethodType; Rec.MethodType)
                {
                    ApplicationArea = All;
                    Editable = true;
                }
                field(ContentType; Rec.ContentType)
                {
                    ApplicationArea = All;
                    Editable = true;
                }
                field(ErrorQueue; Rec.ErrorQueue)
                {
                    ApplicationArea = All;
                    Editable = true;
                }
                field(RoutingKey; Rec.RoutingKey)
                {
                    ApplicationArea = All;
                    Editable = true;
                }
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action("Back")
            {
                ApplicationArea = All;
                Promoted = true;
                PromotedCategory = Process;
                trigger OnAction()
                begin
                    Close();
                end;
            }
        }
    }
}
