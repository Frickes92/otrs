# --
# Kernel/Modules/AgentStatusView.pm - status for all open tickets
# Copyright (C) 2002 Phil Davis <phil.davis at itaction.co.uk>
# Copyright (C) 2001-2004 Martin Edenhofer <martin+code@otrs.org>
# --
# $Id: AgentStatusView.pm,v 1.20.2.2 2004-11-04 06:46:46 martin Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl.txt.
# --

package Kernel::Modules::AgentStatusView;

use strict;
use Kernel::System::State;
use Kernel::System::CustomerUser;

use vars qw($VERSION);
$VERSION = '$Revision: 1.20.2.2 $';
$VERSION =~ s/^\$.*:\W(.*)\W.+?$/$1/;

# --
sub new {
    my $Type = shift;
    my %Param = @_;

    # allocate new hash for object
    my $Self = {};
    bless ($Self, $Type);

    # get common opjects
    foreach (keys %Param) {
        $Self->{$_} = $Param{$_};
    }

    # check all needed objects
    foreach (qw(ParamObject DBObject QueueObject LayoutObject ConfigObject LogObject UserObject)) {
        die "Got no $_" if (!$Self->{$_});
    }
    # needed objects
    $Self->{StateObject} = Kernel::System::State->new(%Param);
    $Self->{CustomerUserObject} = Kernel::System::CustomerUser->new(%Param);
    # --
    # get params
    # --
    $Self->{SortBy} = $Self->{ParamObject}->GetParam(Param => 'SortBy') || 'Age';
    $Self->{Order} = $Self->{ParamObject}->GetParam(Param => 'Order') || 'Up';
    # viewable tickets a page
    $Self->{Limit} = $Self->{ParamObject}->GetParam(Param => 'Limit') || 6000;

    $Self->{StartHit} = $Self->{ParamObject}->GetParam(Param => 'StartHit') || 1;
    $Self->{PageShown} = $Self->{ConfigObject}->Get('AgentStatusView::ViewableTicketsPage') || 50;
    $Self->{ViewType} = $Self->{ParamObject}->GetParam(Param => 'Type') || 'Open';
    if ($Self->{ViewType} =~ /^close/i) {
        $Self->{ViewType} = 'Closed';
    }
    else {
        $Self->{ViewType} = 'Open';
    }

    return $Self;
}
# --
sub Run {
    my $Self = shift;
    my %Param = @_;
    # store last queue screen
    $Self->{SessionObject}->UpdateSessionID(
        SessionID => $Self->{SessionID},
        Key => 'LastScreenOverview',
        Value => $Self->{RequestedURL},
    );
    # store last screen
    $Self->{SessionObject}->UpdateSessionID(
        SessionID => $Self->{SessionID},
        Key => 'LastScreenView',
        Value => $Self->{RequestedURL},
    );
    # starting with page ...
    my $Refresh = '';
    if ($Self->{UserRefreshTime}) {
        $Refresh = 60 * $Self->{UserRefreshTime};
    }
    my $Output = $Self->{LayoutObject}->Header(
       Area => 'Agent',
       Title => 'Status View',
       Refresh => $Refresh,
    );
    # build NavigationBar
    $Output .= $Self->{LayoutObject}->NavigationBar();
    # to get the output faster!
    print $Output; $Output = '';

    if ($Self->{ViewType} =~ /close/i) {
        $Self->{ViewType} = 'Closed';
    }
    else {
        $Self->{ViewType} = 'Open';
    }
    # get shown tickets
    my @TicketIDs = $Self->{TicketObject}->TicketSearch(
        Result => 'ARRAY',
        Limit => $Self->{Limit},
        StateType => $Self->{ViewType},
        OrderBy => $Self->{Order},
        SortBy => $Self->{SortBy},
        UserID => $Self->{UserID},
        Permission => 'ro',
    );
    # show ticket's
    my $Counter = 0;
    foreach my $TicketID (@TicketIDs) {
        $Counter++;
        if ($Counter >= $Self->{StartHit} && $Counter < ($Self->{PageShown}+$Self->{StartHit})) {
            # get last customer article
            my %Article = $Self->{TicketObject}->ArticleLastCustomerArticle(TicketID => $TicketID);
            # create human age
            $Article{Age} = $Self->{LayoutObject}->CustomerAge(Age => $Article{Age}, Space => ' ');
            # customer info (customer name)
            my %CustomerData = ();
            if ($Article{CustomerUserID}) {
                %CustomerData = $Self->{CustomerUserObject}->CustomerUserDataGet(
                    User => $Article{CustomerUserID},
                );
            }
            if ($CustomerData{UserLogin}) {
                $Article{CustomerName} = $Self->{CustomerUserObject}->CustomerName(
                    UserLogin => $CustomerData{UserLogin},
                );
            }
            # user info
            my %UserInfo = $Self->{UserObject}->GetUserData(
                User => $Article{Owner},
                Cached => 1
            );

            $Self->{LayoutObject}->Block(
                Name => 'Record',
                Data => { %Article, %UserInfo },
            );
        }
    }


    # build search navigation bar
    my %PageNav = $Self->{LayoutObject}->PageNavBar(
        Limit => $Self->{Limit},
        StartHit => $Self->{StartHit},
        PageShown => $Self->{PageShown},
        AllHits => $Counter,
        Action => "Action=AgentStatusView&",
        Link => "SortBy=$Self->{SortBy}&Order=$Self->{Order}&Type=$Self->{ViewType}&",
    );

    # use template
    $Output .= $Self->{LayoutObject}->Output(
        TemplateFile => 'AgentStatusView',
        Data => { %Param, %PageNav, Type => $Self->{ViewType}, },
    );

    # get page footer
    $Output .= $Self->{LayoutObject}->Footer();

    # return page
    return $Output;
}

1;
