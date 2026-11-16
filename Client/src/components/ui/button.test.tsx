import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import { Button } from "./button";

describe("Button", () => {
  it("renders its label and forwards click events", async () => {
    const user = userEvent.setup();
    const onClick = vi.fn();

    render(<Button onClick={onClick}>Save changes</Button>);

    const button = screen.getByRole("button", { name: "Save changes" });
    await user.click(button);

    expect(onClick).toHaveBeenCalledOnce();
  });

  it("supports the outline variant", () => {
    render(<Button variant="outline">Cancel</Button>);

    expect(screen.getByRole("button", { name: "Cancel" })).toHaveClass(
      "border-border",
    );
  });
});
