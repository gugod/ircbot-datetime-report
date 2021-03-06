#!/usr/bin/env perl
use v5.18;
use strict;
use warnings;

use Getopt::Long qw(GetOptions);

use Data::Printer;

use Mojo::JSON qw(decode_json);
use Mojo::IOLoop;
use Mojo::Util;
use Mojo::IRC;
use Mojo::IRC::UA;
use IRC::Utils ();

sub is_prime {
    my $n = $_[0];
    my $qn = sqrt($n);
    for (my $i = 2; $i < $qn; $i++) {
        return 0 if $n % $i == 0;
    }
    return 1;
}

my $CONTEXT = {};

sub irc_init {
    my ($nick, $server, $channel) = @_;
    my $irc;

    $irc = Mojo::IRC::UA->new(
        nick => $nick,
        user => $nick,
        server => $server,
    );

    $irc->on(
        error => sub {
            my ($self, $message) = @_;
            $CONTEXT->{errors}++;
            p($message);

            Mojo::IOLoop->timer(
                10, sub {
                    $irc->connect(sub {});
                }
            );
        }) unless $irc->has_subscribers('error');

    $irc->on(
        irc_join => sub {
            my($self, $message) = @_;
            p($message);

        }) unless $irc->has_subscribers('irc_join');

    $irc->on(
        irc_privmsg => sub {
            my($self, $message) = @_;
            p($message);
        }) unless $irc->has_subscribers('irc_privmsg');

    $irc->on(
        irc_rpl_welcome => sub {
            say "-- connected";
            $irc->join_channel(
                $channel,
                sub {
                    my ($self, $err, $info) = @_;
                    say "-- join $channel -- topic - $info->{topic}";
                }
            );
        }) unless $irc->has_subscribers('irc_rpl_welcome');

    $irc->op_timeout(120);
    $irc->register_default_event_handlers;

    $irc->connect(sub {
                      my ($self, $err, $info) = @_;
                      if (!$err) {
                          say "-- connected";
                      } else {
                          say "-- error connecting -- $err";
                      }
                  });

    Mojo::IOLoop->recurring(
        1 , sub {
            my $t = time;
            my $text;
            if (is_prime($t)) {
                $text = "PRIME TIME: " . localtime($t) . " , epoch: $t";
            }

            if ($text) {
                $irc->write(PRIVMSG => $channel, ":$text\n", sub {});
            }
        }
    );

    return $irc;
}

sub MAIN {
    my %args = @_;

    $CONTEXT->{irc_bot} //= irc_init($args{irc_nickname}, $args{irc_server}, $args{irc_channel});

    Mojo::IOLoop->start;
}


my %args;
GetOptions(
    \%args,
    "irc_nickname=s",
    "irc_server=s",
    "irc_channel=s",
);
MAIN(%args);
